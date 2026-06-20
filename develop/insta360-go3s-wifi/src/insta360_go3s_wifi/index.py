"""Local JSON index for imported camera files."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

INDEX_DIR_NAME = ".insta360-go3s-wifi"
INDEX_FILE_NAME = "index.json"
INDEX_VERSION = 1


def index_path_for(dest_dir: Path) -> Path:
    return dest_dir / INDEX_DIR_NAME / INDEX_FILE_NAME


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


@dataclass
class IndexedFile:
    remote_path: str
    local_name: str
    size: int
    imported_at: str

    @classmethod
    def from_dict(cls, data: dict) -> "IndexedFile":
        return cls(
            remote_path=data["remote_path"],
            local_name=data["local_name"],
            size=int(data.get("size", 0)),
            imported_at=data.get("imported_at", ""),
        )

    def to_dict(self) -> dict:
        return {
            "remote_path": self.remote_path,
            "local_name": self.local_name,
            "size": self.size,
            "imported_at": self.imported_at,
        }


@dataclass
class ImportIndex:
    dest_dir: Path
    version: int = INDEX_VERSION
    updated_at: str = field(default_factory=_utc_now_iso)
    files: Dict[str, IndexedFile] = field(default_factory=dict)

    @property
    def path(self) -> Path:
        return index_path_for(self.dest_dir)

    @classmethod
    def load(cls, dest_dir: Path) -> "ImportIndex":
        dest_dir = dest_dir.expanduser().resolve()
        path = index_path_for(dest_dir)
        if not path.is_file():
            return cls(dest_dir=dest_dir)

        try:
            with open(path, encoding="utf-8") as handle:
                raw = json.load(handle)
        except (json.JSONDecodeError, OSError, ValueError, TypeError):
            return cls(dest_dir=dest_dir)

        files: Dict[str, IndexedFile] = {}
        for remote_path, entry in raw.get("files", {}).items():
            if not isinstance(entry, dict):
                continue
            try:
                files[remote_path] = IndexedFile.from_dict(entry)
            except (KeyError, TypeError, ValueError):
                continue

        return cls(
            dest_dir=dest_dir,
            version=int(raw.get("version", INDEX_VERSION)),
            updated_at=raw.get("updated_at", ""),
            files=files,
        )

    def save(self) -> None:
        self.updated_at = _utc_now_iso()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": self.version,
            "updated_at": self.updated_at,
            "files": {
                remote_path: entry.to_dict()
                for remote_path, entry in sorted(self.files.items())
            },
        }
        temp_path = self.path.with_suffix(".json.tmp")
        with open(temp_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.replace(temp_path, self.path)

    def local_path(self, local_name: str) -> Path:
        return self.dest_dir / local_name

    def is_imported(self, remote_path: str) -> bool:
        entry = self.files.get(remote_path)
        if entry is None:
            return False
        local = self.local_path(entry.local_name)
        if not local.is_file():
            return False
        size = local.stat().st_size
        if size <= 0:
            return False
        if entry.size > 0 and size != entry.size:
            return False
        return True

    def is_imported_remote(self, remote_path: str) -> bool:
        """True if indexed import or a local MP4 with the same filename exists."""
        if self.is_imported(remote_path):
            return True
        from insta360_go3s_wifi.files import local_name

        name = local_name(remote_path)
        if not name.lower().endswith(".mp4"):
            return False
        local = self.local_path(name)
        if not local.is_file():
            return False
        return local.stat().st_size > 0

    def imported_mp4_paths(self, mp4_files: List[str]) -> set:
        return {path for path in mp4_files if self.is_imported_remote(path)}

    def mark_imported(self, remote_path: str, local_name: str, size: int) -> None:
        self.files[remote_path] = IndexedFile(
            remote_path=remote_path,
            local_name=local_name,
            size=size,
            imported_at=_utc_now_iso(),
        )

    def remove(self, remote_path: str) -> None:
        self.files.pop(remote_path, None)
