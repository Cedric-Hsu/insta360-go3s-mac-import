"""Camera session wrapper (GO 3S native protocol first)."""

from __future__ import annotations

from contextlib import contextmanager
from typing import Callable, Generator, List, Optional, Tuple

from insta360_go3s_wifi.downloader import ProgressCallback, download_remote_file
from insta360_go3s_wifi.go3s_protocol import Go3sProtocolError, Go3sSession, probe_tcp_handshake
from insta360_go3s_wifi.network import DEFAULT_CAMERA_HOST, DEFAULT_CAMERA_PORT
from insta360_go3s_wifi.perf_log import log_event, timed_step


class CameraConnectionError(RuntimeError):
    pass


class CameraClient:
    def __init__(
        self,
        host: str = DEFAULT_CAMERA_HOST,
        port: int = DEFAULT_CAMERA_PORT,
    ) -> None:
        self.host = host
        self.port = port
        self._session: Optional[Go3sSession] = None

    def open(self, require_sync: bool = False) -> None:
        session = Go3sSession(host=self.host, port=self.port, require_sync=require_sync)
        try:
            with timed_step("client", "connect", host=self.host, port=self.port):
                session.connect()
        except Go3sProtocolError as exc:
            raise CameraConnectionError(str(exc)) from exc
        self._session = session
        log_event(
            "client",
            "connected",
            extra={"host": self.host, "connect_mode": session.connect_mode},
        )

    @property
    def connect_mode(self) -> str:
        if self._session is None:
            return "disconnected"
        return self._session.connect_mode or "unknown"

    def close(self) -> None:
        if self._session is not None:
            self._session.close()
            self._session = None

    def list_files(self) -> List[str]:
        if self._session is None:
            raise CameraConnectionError("Camera client is not connected")
        try:
            with timed_step("client", "list_files", host=self.host):
                files = self._session.list_all_files()
            log_event("client", "list_files result", extra={"count": len(files)})
            return files
        except Go3sProtocolError as exc:
            raise CameraConnectionError(str(exc)) from exc

    def list_files_range(
        self,
        *,
        start: int = 0,
        page_size: int = 100,
        max_pages: Optional[int] = 1,
    ) -> Tuple[List[str], Optional[int], bool, int]:
        if self._session is None:
            raise CameraConnectionError("Camera client is not connected")
        try:
            with timed_step(
                "client",
                "list_files_range",
                host=self.host,
                start=start,
                page_size=page_size,
                max_pages=max_pages,
            ):
                result = self._session.list_files_range(
                    start=start,
                    page_size=page_size,
                    max_pages=max_pages,
                )
            paths, total, has_more, next_start = result
            log_event(
                "client",
                "list_files_range result",
                extra={
                    "count": len(paths),
                    "total": total,
                    "has_more": has_more,
                    "next_start": next_start,
                },
            )
            return result
        except Go3sProtocolError as exc:
            raise CameraConnectionError(str(exc)) from exc

    def download(
        self,
        remote_path: str,
        local_path: str,
        progress_callback: Optional[ProgressCallback] = None,
        should_cancel: Optional[Callable[[], bool]] = None,
    ) -> bool:
        try:
            return download_remote_file(
                remote_path,
                local_path,
                host=self.host,
                progress_callback=progress_callback,
                should_cancel=should_cancel,
            )
        except OSError as exc:
            raise CameraConnectionError(f"HTTP download failed: {exc}") from exc


@contextmanager
def connected_camera(
    host: str = DEFAULT_CAMERA_HOST,
    port: int = DEFAULT_CAMERA_PORT,
) -> Generator[CameraClient, None, None]:
    camera = CameraClient(host=host, port=port)
    camera.open()
    try:
        yield camera
    finally:
        camera.close()
