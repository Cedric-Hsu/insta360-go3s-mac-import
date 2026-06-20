"""Minimal synchronous WiFi client for Insta360 GO 3S (TCP 6666 + HTTP 80)."""

from __future__ import annotations

import socket
import struct
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from google.protobuf import json_format
from insta360.pb2 import (
    check_authorization_pb2,
    get_file_list_pb2,
    set_access_camera_file_state_pb2,
    set_options_pb2,
)
from insta360_go3s_wifi.perf_log import log_event, timed_step

PKT_SYNC = b"\x06\x00\x00syNceNdinS"
PKT_KEEPALIVE = b"\x05\x00\x00"
SYNC_MAGIC = b"syNceNdinS"

CMD_BEGIN = 0
CMD_SET_OPTIONS = 7
CMD_GET_FILE_LIST = 13
CMD_OPEN_CAMERA_WIFI = 33
CMD_CHECK_AUTHORIZATION = 39
CMD_SET_ACCESS_CAMERA_FILE_STATE = 118

RESPONSE_OK = 200
RESPONSE_ERROR = 500

READ_TIMEOUT_SEC = 0.35
CONNECT_TIMEOUT_SEC = 5.0
# GO 3S returns at most ~100 entries per GET_FILE_LIST page regardless of limit.
CAMERA_PAGE_SIZE = 100


class Go3sProtocolError(RuntimeError):
    pass


def _hex_preview(data: bytes, limit: int = 96) -> str:
    if not data:
        return "(empty)"
    chunk = data[:limit]
    text = chunk.hex(" ")
    if len(data) > limit:
        text += " ..."
    return text


def _recv_chunk(sock: socket.socket) -> bytes:
    try:
        return sock.recv(4096)
    except socket.timeout:
        return b""
    except OSError:
        return b""


def probe_tcp_handshake(
    host: str,
    port: int = 6666,
    listen_sec: float = 1.5,
    attempts: int = 3,
) -> Tuple[bool, str, bytes]:
    """Connect, optionally read camera-initiated bytes, try SYNC; return summary + raw bytes."""
    collected = bytearray()
    reset = False
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(CONNECT_TIMEOUT_SEC)
    try:
        sock.connect((host, port))
        sock.settimeout(READ_TIMEOUT_SEC)

        deadline = time.monotonic() + listen_sec
        while time.monotonic() < deadline:
            chunk = _recv_chunk(sock)
            if not chunk:
                if not collected:
                    time.sleep(0.05)
                    continue
                break
            collected.extend(chunk)

        sync_seen = False
        for _ in range(attempts):
            try:
                sock.sendall(_frame(PKT_SYNC))
                sock.sendall(_frame(PKT_KEEPALIVE))
            except OSError:
                reset = True
                break
            deadline = time.monotonic() + 2.0
            while time.monotonic() < deadline:
                chunk = _recv_chunk(sock)
                if not chunk:
                    continue
                collected.extend(chunk)
                if _payload_has_sync(bytes(collected)):
                    sync_seen = True
                    break
            if sync_seen:
                break

        summary = (
            f"bytes={len(collected)} sync={'yes' if sync_seen else 'no'} "
            f"reset={'yes' if reset else 'no'} "
            f"preview={_hex_preview(bytes(collected))}"
        )
        banner_seen = len(collected) >= 4 and not sync_seen
        return sync_seen, summary, bytes(collected), banner_seen
    except OSError as exc:
        summary = f"connect failed: {exc}; collected={_hex_preview(bytes(collected))}"
        return False, summary, bytes(collected), False
    finally:
        sock.close()


def _frame(payload: bytes) -> bytes:
    return struct.pack("<I", len(payload) + 4) + payload


def _payload_has_sync(payload: bytes) -> bool:
    if payload == PKT_SYNC:
        return True
    if SYNC_MAGIC in payload:
        return True
    return False


@dataclass
class Go3sSession:
    host: str
    port: int = 6666
    require_sync: bool = False
    _socket: Optional[socket.socket] = field(default=None, init=False, repr=False)
    _seq: int = field(default=0, init=False, repr=False)
    _buffer: bytes = field(default=b"", init=False, repr=False)
    connect_mode: str = field(default="", init=False, repr=False)
    sync_echo_received: bool = field(default=False, init=False, repr=False)
    initial_banner: bytes = field(default=b"", init=False, repr=False)

    def connect(self) -> None:
        with timed_step("go3s", "connect", host=self.host, port=self.port):
            self.close()
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(CONNECT_TIMEOUT_SEC)
            sock.connect((self.host, self.port))
            sock.settimeout(READ_TIMEOUT_SEC)
            self._socket = sock
            self._buffer = b""

            with timed_step("go3s", "drain_banner", host=self.host):
                self.initial_banner = self._drain_for(0.8)

            banner_detected = bool(self.initial_banner or self._buffer)

            if banner_detected:
                # GO 3S often sends a short banner; skip long SYNC loops (~20s).
                self.connect_mode = "banner"
                self._seq = 0
                self.sync_echo_received = False
                log_event(
                    "go3s",
                    "banner_fast_path",
                    extra={"banner_bytes": len(self.initial_banner), "buffer_bytes": len(self._buffer)},
                )
            else:
                with timed_step("go3s", "sync_handshake", host=self.host):
                    sync_ok = self._attempt_sync_handshake(rounds=3, wait_each=1.0)
                self.sync_echo_received = sync_ok

                if sync_ok:
                    self.connect_mode = "sync"
                    with timed_step("go3s", "session_warmup", host=self.host):
                        self._run_session_warmup()
                elif self.require_sync:
                    raise Go3sProtocolError(
                        "SYNC handshake failed (no echo). "
                        "Start Quick File Transfer on Action Pod, then retry within 30s."
                    )
                else:
                    self.connect_mode = "no_response"
                    with timed_step("go3s", "session_warmup", host=self.host):
                        self._run_session_warmup()
        log_event(
            "go3s",
            "connect result",
            extra={
                "host": self.host,
                "connect_mode": self.connect_mode,
                "sync_echo": self.sync_echo_received,
                "banner_bytes": len(self.initial_banner),
            },
        )

    def close(self) -> None:
        if self._socket is not None:
            try:
                self._socket.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            self._socket.close()
        self._socket = None
        self._buffer = b""

    def list_files(self, limit: int = 500, start: int = 0) -> List[str]:
        uris, _ = self.list_files_page(limit=limit, start=start)
        return uris

    def list_all_files(self, page_size: int = CAMERA_PAGE_SIZE) -> List[str]:
        """Fetch all remote paths, following camera pagination."""
        paths, _, _, _ = self.list_files_range(start=0, page_size=page_size, max_pages=None)
        return paths

    def list_files_range(
        self,
        *,
        start: int = 0,
        page_size: int = CAMERA_PAGE_SIZE,
        max_pages: Optional[int] = 1,
    ) -> Tuple[List[str], Optional[int], bool, int]:
        """Return (paths, total, has_more, next_start) for one or more camera pages."""
        component = "go3s"
        step = "list_all_files" if max_pages is None else "list_files_range"
        fields = {"host": self.host, "page_size": page_size, "start": start, "max_pages": max_pages}
        with timed_step(component, step, **fields):
            all_uris: List[str] = []
            current_start = start
            total: Optional[int] = None
            page_index = 0

            while max_pages is None or page_index < max_pages:
                page_index += 1
                with timed_step(
                    component,
                    "list_files_page",
                    host=self.host,
                    start=current_start,
                    page_size=page_size,
                    page_index=page_index,
                ):
                    page, total = self.list_files_page(limit=page_size, start=current_start)
                log_event(
                    component,
                    "list_files_page result",
                    extra={
                        "page_index": page_index,
                        "start": current_start,
                        "page_count": len(page),
                        "total": total,
                        "accumulated": len(all_uris) + len(page),
                    },
                )
                if not page:
                    break
                all_uris.extend(page)
                current_start += len(page)
                if total is not None and current_start >= total:
                    break
                if total is None and len(page) < page_size:
                    break

            next_start = current_start
            has_more = bool(total is not None and next_start < total)
            log_event(
                component,
                f"{step} result",
                extra={"count": len(all_uris), "total": total, "has_more": has_more, "next_start": next_start},
            )
            return all_uris, total, has_more, next_start

    def list_files_page(
        self,
        limit: int = 100,
        start: int = 0,
    ) -> Tuple[List[str], Optional[int]]:
        if self.connect_mode == "banner":
            self._seq = 0
            self._prepare_banner_file_access()

        errors: List[str] = []
        for label, body in self._file_list_page_bodies(limit=limit, start=start):
            self._seq = 0
            try:
                response_body = self._send_command(
                    CMD_GET_FILE_LIST,
                    body,
                    wait_seconds=25.0,
                )
                response = get_file_list_pb2.GetFileListResp()
                response.ParseFromString(response_body)
                total = response.total_count if response.total_count else None
                return list(response.uri), total
            except Go3sProtocolError as exc:
                errors.append(f"{label}: {exc}")

        detail = "; ".join(errors) if errors else "no strategies attempted"
        raise Go3sProtocolError(
            f"GET_FILE_LIST failed ({detail}). "
            f"sync_echo={self.sync_echo_received}, connect_mode={self.connect_mode}. "
            "Enable Action Pod Quick File Transfer, then retry within 30s."
        )

    def _attempt_sync_handshake(self, rounds: int, wait_each: float) -> bool:
        for _ in range(rounds):
            self._send_raw(PKT_SYNC)
            self._send_raw(PKT_KEEPALIVE)
            if self._wait_for_sync_echo(wait_each):
                return True
            time.sleep(0.15)
        return False

    def _attempt_post_banner_sync(self, *, rounds: int = 8, wait_each: float = 1.0) -> bool:
        """GO 3S may send a short banner before accepting SYNC."""
        for _ in range(rounds):
            self._send_raw(PKT_KEEPALIVE)
            self._send_raw(PKT_SYNC)
            if self._wait_for_sync_echo(wait_each):
                return True
            time.sleep(0.1)
        return False

    def _run_session_warmup(self) -> None:
        for code in (CMD_BEGIN, CMD_OPEN_CAMERA_WIFI):
            try:
                self._send_command(code, b"", wait_seconds=3.0)
            except Go3sProtocolError:
                pass
        try:
            self._sync_time()
        except Go3sProtocolError:
            pass

    def _prepare_banner_file_access(self) -> None:
        """Best-effort activation before GET_FILE_LIST in banner-only mode."""
        self._attempt_post_banner_sync(rounds=2, wait_each=0.4)
        access_msg = {"state": "EXPORT"}
        access_body = self._serialize(
            set_access_camera_file_state_pb2.SetAccessCameraFileState(),
            access_msg,
        )
        auth_body = self._serialize(
            check_authorization_pb2.CheckAuthorization(),
            {"id": ""},
        )
        for code, body in (
            (CMD_SET_ACCESS_CAMERA_FILE_STATE, access_body),
            (CMD_CHECK_AUTHORIZATION, auth_body),
            (CMD_BEGIN, b""),
        ):
            try:
                self._send_command(code, body, wait_seconds=4.0)
            except Go3sProtocolError:
                pass

    def _file_list_page_bodies(self, limit: int, start: int) -> List[Tuple[str, bytes]]:
        strategies: List[Tuple[str, Dict]] = [
            (
                "video_and_photo",
                {"media_type": "VIDEO_AND_PHOTO", "limit": limit, "start": start},
            ),
            ("video_only", {"media_type": "VIDEO", "limit": limit, "start": start}),
        ]
        bodies: List[Tuple[str, bytes]] = []
        for label, message in strategies:
            proto = get_file_list_pb2.GetFileList()
            bodies.append((label, self._serialize(proto, message)))
        return bodies

    def _file_list_request_bodies(self, limit: int) -> List[Tuple[str, bytes]]:
        return self._file_list_page_bodies(limit=limit, start=0)

    def _sync_time(self) -> None:
        message = {
            "optionTypes": ["LOCAL_TIME", "TIME_ZONE"],
            "value": {
                "local_time": int(time.time()),
                "time_zone_seconds_from_GMT": 0,
            },
        }
        body = self._serialize(set_options_pb2.SetOptions(), message)
        self._send_command(CMD_SET_OPTIONS, body, wait_seconds=5.0)

    def _serialize(self, proto_msg, message: Dict) -> bytes:
        json_format.ParseDict(message, proto_msg)
        return proto_msg.SerializeToString()

    def _next_seq(self) -> int:
        self._seq += 1
        return self._seq

    def _send_raw(self, payload: bytes) -> None:
        if self._socket is None:
            raise Go3sProtocolError("Not connected")
        self._socket.sendall(_frame(payload))

    def _send_command(
        self,
        code: int,
        protobuf_body: bytes,
        wait_seconds: float = 20.0,
    ) -> bytes:
        seq = self._next_seq()
        header = b"\x04\x00\x00"
        header += code.to_bytes(2, "little")
        header += b"\x02"
        header += struct.pack("<I", seq)[0:3]
        header += b"\x80\x00\x00"
        self._send_raw(header + protobuf_body)
        return self._wait_command_response(seq, code, wait_seconds=wait_seconds)

    def _drain_for(self, seconds: float) -> bytes:
        end = time.monotonic() + seconds
        drained = bytearray()
        while time.monotonic() < end:
            for payload in self._read_packets(deadline=min(0.3, end - time.monotonic())):
                drained.extend(payload)
        return bytes(drained)

    def _wait_for_sync_echo(self, deadline: float = 5.0) -> bool:
        end = time.monotonic() + deadline
        while time.monotonic() < end:
            for payload in self._read_packets(deadline=min(0.4, end - time.monotonic())):
                if _payload_has_sync(payload):
                    return True
        return False

    def _wait_command_response(
        self,
        seq: int,
        sent_code: int,
        wait_seconds: float = 20.0,
    ) -> bytes:
        deadline = time.monotonic() + wait_seconds
        while time.monotonic() < deadline:
            for payload in self._read_packets(deadline=min(0.5, deadline - time.monotonic())):
                if len(payload) < 12:
                    if _payload_has_sync(payload):
                        continue
                    continue
                if payload[0:3] != b"\x04\x00\x00":
                    continue
                response_code = struct.unpack("<H", payload[3:5])[0]
                response_seq = struct.unpack("<I", payload[6:9] + b"\x00")[0]
                body = payload[12:]
                if response_seq != seq:
                    continue
                if response_code == RESPONSE_ERROR:
                    raise Go3sProtocolError(f"Command {sent_code} failed: {body!r}")
                if response_code == RESPONSE_OK:
                    return body
        raise Go3sProtocolError(
            f"Command {sent_code} (seq {seq}) timed out with no response "
            f"(connect_mode={self.connect_mode or 'unknown'})"
        )

    def _read_packets(self, deadline: float = 1.0) -> List[bytes]:
        if self._socket is None:
            return []
        end = time.monotonic() + deadline
        packets: List[bytes] = []
        while time.monotonic() < end:
            try:
                chunk = self._socket.recv(4096)
            except socket.timeout:
                break
            except OSError:
                break
            if not chunk:
                break
            self._buffer += chunk
            while len(self._buffer) >= 4:
                total = struct.unpack("<I", self._buffer[0:4])[0]
                if total < 4 or total > 16_777_216:
                    self._buffer = self._buffer[1:]
                    continue
                if len(self._buffer) < total:
                    break
                payload = self._buffer[4:total]
                self._buffer = self._buffer[total:]
                packets.append(payload)
            if packets:
                return packets
        return packets
