"""Phase 1 verification workflow for GO 3S."""

from __future__ import annotations

import os
import time
from dataclasses import dataclass, field
from typing import List, Optional

from insta360_go3s_wifi.client import CameraClient, CameraConnectionError
from insta360_go3s_wifi.diagnose import run_diagnose
from insta360_go3s_wifi.files import (
    group_mp4_with_lrv,
    local_name,
    pick_smallest_mp4,
)
from insta360_go3s_wifi.network import DEFAULT_CAMERA_HOST, check_wifi_for_go3s, ping_host


@dataclass
class StepResult:
    name: str
    ok: bool
    detail: str


@dataclass
class VerifyReport:
    steps: List[StepResult] = field(default_factory=list)
    downloaded_files: List[str] = field(default_factory=list)
    download_seconds: Optional[float] = None
    download_bytes: Optional[int] = None

    @property
    def passed(self) -> bool:
        return all(step.ok for step in self.steps)

    def add(self, name: str, ok: bool, detail: str) -> None:
        self.steps.append(StepResult(name=name, ok=ok, detail=detail))

    def to_markdown(self) -> str:
        lines = [
            "## Phase 1 auto-run",
            "",
            f"- Date: {time.strftime('%Y-%m-%d %H:%M:%S')}",
            f"- Overall: {'PASS' if self.passed else 'FAIL'}",
            "",
            "| Step | Result | Detail |",
            "|------|--------|--------|",
        ]
        for step in self.steps:
            mark = "PASS" if step.ok else "FAIL"
            detail = step.detail.replace("|", "\\|")
            lines.append(f"| {step.name} | {mark} | {detail} |")

        if self.downloaded_files:
            lines.extend(["", "### Downloaded", ""])
            for path in self.downloaded_files:
                size = os.path.getsize(path) if os.path.isfile(path) else 0
                lines.append(f"- `{path}` ({size} bytes)")
            if self.download_seconds and self.download_bytes:
                rate = self.download_bytes / self.download_seconds / (1024 * 1024)
                lines.append(f"- Throughput ~{rate:.2f} MB/s")

        return "\n".join(lines) + "\n"


def _wifi_step() -> StepResult:
    wifi = check_wifi_for_go3s()
    ping = ping_host(DEFAULT_CAMERA_HOST, count=1)
    if ping.ok:
        return StepResult(
            name="WiFi / camera link",
            ok=True,
            detail=f"ping 192.168.42.1 OK; SSID={wifi.ssid or 'unknown'}",
        )
    if wifi.ssid and wifi.ssid != "<redacted>" and wifi.looks_like_go3s:
        return StepResult(
            name="WiFi / camera link",
            ok=True,
            detail=f"connected to `{wifi.ssid}`",
        )
    return StepResult(
        name="WiFi / camera link",
        ok=False,
        detail=f"SSID={wifi.ssid or 'unknown'}; {ping.message}",
    )


def run_probe(host: str = DEFAULT_CAMERA_HOST) -> VerifyReport:
    report = VerifyReport()
    wifi_step = _wifi_step()
    report.add(wifi_step.name, wifi_step.ok, wifi_step.detail)

    ping = ping_host(host)
    report.add("ping camera", ping.ok, ping.message)

    diagnose = run_diagnose(host)
    for step in diagnose.steps:
        if step.message.startswith("ping"):
            continue
        name = step.message.split()[0] if step.message else "check"
        report.add(name, step.ok, step.message)

    return report


def run_verify(
    host: str = DEFAULT_CAMERA_HOST,
    download_dir: str = "./test-download",
    skip_download: bool = False,
) -> VerifyReport:
    report = VerifyReport()

    wifi_step = _wifi_step()
    report.add(wifi_step.name, wifi_step.ok, wifi_step.detail)

    ping = ping_host(host)
    report.add("ping camera", ping.ok, ping.message)

    remote_files: List[str] = []
    camera: Optional[CameraClient] = None
    connect_ok = False
    try:
        camera = CameraClient(host=host)
        camera.open()
        connect_ok = True
        report.add("TCP SYNC + open", True, f"connected ({camera.connect_mode})")
        if camera._session and camera._session.initial_banner:
            report.add(
                "initial banner",
                True,
                camera._session.initial_banner.hex(" ") or "(empty)",
            )
        if camera._session and not camera._session.sync_echo_received:
            report.add(
                "SYNC echo",
                False,
                "camera sent banner but no syNceNdinS echo; file commands may fail",
            )

        try:
            remote_files = camera.list_files()
        except CameraConnectionError as exc:
            report.add("GET_FILE_LIST", False, str(exc))
            report.add(
                "hint",
                False,
                "Try Action Pod Quick File Transfer, or connect Insta360 app once via BLE",
            )
            return report

        has_dcim = any("DCIM/Camera01" in path for path in remote_files)
        report.add(
            "GET_FILE_LIST",
            len(remote_files) > 0,
            f"{len(remote_files)} files; DCIM path present={has_dcim}",
        )

        if skip_download:
            return report

        smallest = pick_smallest_mp4(remote_files)
        if smallest is None:
            report.add("download test", False, "no MP4 found on camera")
            return report

        os.makedirs(download_dir, exist_ok=True)
        targets = group_mp4_with_lrv(smallest, remote_files)
        total_bytes = 0
        started = time.monotonic()

        for remote_path in targets:
            dest = os.path.join(download_dir, local_name(remote_path))
            ok = camera.download(remote_path, dest)
            if not ok or not os.path.isfile(dest):
                report.add(
                    "download test",
                    False,
                    f"failed to download {remote_path}",
                )
                return report
            total_bytes += os.path.getsize(dest)
            report.downloaded_files.append(dest)

        elapsed = time.monotonic() - started
        report.download_seconds = elapsed
        report.download_bytes = total_bytes
        report.add(
            "download test",
            True,
            f"downloaded {len(targets)} file(s) in {elapsed:.1f}s",
        )
    except CameraConnectionError as exc:
        if not connect_ok:
            report.add("TCP SYNC + open", False, str(exc))
            if camera and camera._session and camera._session.initial_banner:
                report.add(
                    "initial banner",
                    False,
                    camera._session.initial_banner.hex(" "),
                )
            report.add(
                "hint",
                False,
                "Try Action Pod Quick File Transfer, or connect Insta360 app once via BLE",
            )
    finally:
        if camera is not None:
            camera.close()

    return report
