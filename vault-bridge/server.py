#!/usr/bin/env python3
import argparse
import hashlib
import json
import mimetypes
import os
import posixpath
import threading
from dataclasses import dataclass
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import parse_qs, unquote, urlparse

VERSION = "0.1.0"


@dataclass
class VideoEntry:
    id: str
    filename: str
    relative_path: str
    size: int
    modified_at: str
    mime_type: str
    absolute_path: Path


class VideoIndex:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self._lock = threading.Lock()
        self._by_id: Dict[str, VideoEntry] = {}
        self._folders: Dict[str, set[str]] = {}

    def rebuild(self) -> None:
        by_id: Dict[str, VideoEntry] = {}
        folders: Dict[str, set[str]] = {"": set()}

        for file_path in self.root.rglob("*"):
            if not file_path.is_file():
                continue

            # Resolve symlinks and keep a strict root jail: if a link escapes the
            # configured root, skip it.
            try:
                resolved = file_path.resolve(strict=True)
                resolved.relative_to(self.root)
            except Exception:
                continue

            rel = file_path.relative_to(self.root).as_posix()
            stat = file_path.stat()
            mime = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
            modified = datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat()
            digest = hashlib.sha256(f"{rel}|{stat.st_size}|{int(stat.st_mtime)}".encode("utf-8")).hexdigest()[:20]

            entry = VideoEntry(
                id=digest,
                filename=file_path.name,
                relative_path=rel,
                size=stat.st_size,
                modified_at=modified,
                mime_type=mime,
                absolute_path=file_path,
            )
            by_id[entry.id] = entry

            parent = posixpath.dirname(rel)
            folders.setdefault(parent, set())

            parts = rel.split("/")
            for i in range(len(parts) - 1):
                parent_path = "/".join(parts[:i])
                child = parts[i]
                folders.setdefault(parent_path, set()).add(child)

        with self._lock:
            self._by_id = by_id
            self._folders = folders

    def list_path(self, rel_path: str) -> tuple[List[dict], List[dict]]:
        rel_path = normalize_relative_path(rel_path)
        with self._lock:
            if rel_path not in self._folders and rel_path != "":
                return [], []

            folder_names = sorted(self._folders.get(rel_path, set()), key=str.lower)
            folder_objs = []
            for name in folder_names:
                child_path = posixpath.join(rel_path, name) if rel_path else name
                folder_objs.append({"name": name, "path": child_path})

            file_objs = []
            for entry in self._by_id.values():
                if posixpath.dirname(entry.relative_path) == rel_path:
                    file_objs.append(self._to_wire(entry))
            file_objs.sort(key=lambda f: f["filename"].lower())

            return folder_objs, file_objs

    def search(self, q: str, rel_path: Optional[str]) -> List[dict]:
        q_lower = q.lower()
        prefix = normalize_relative_path(rel_path or "")

        with self._lock:
            matches = []
            for entry in self._by_id.values():
                if prefix and not entry.relative_path.startswith(prefix + "/") and entry.relative_path != prefix:
                    continue
                if q_lower in entry.filename.lower() or q_lower in entry.relative_path.lower():
                    matches.append(self._to_wire(entry))
            matches.sort(key=lambda f: f["filename"].lower())
            return matches

    def get(self, video_id: str) -> Optional[VideoEntry]:
        with self._lock:
            return self._by_id.get(video_id)

    @staticmethod
    def _to_wire(entry: VideoEntry) -> dict:
        return {
            "id": entry.id,
            "filename": entry.filename,
            "relativePath": entry.relative_path,
            "size": entry.size,
            "modifiedAt": entry.modified_at,
            "mimeType": entry.mime_type,
        }


def normalize_relative_path(raw_path: str) -> str:
    decoded = unquote(raw_path or "")
    if ".." in decoded.replace("\\", "/").split("/"):
        raise ValueError("Path traversal is not allowed")

    cleaned = posixpath.normpath(decoded).strip()

    if cleaned in (".", "/"):
        return ""

    cleaned = cleaned.lstrip("/")
    return cleaned


class VaultHandler(BaseHTTPRequestHandler):
    server: "VaultServer"

    def do_GET(self) -> None:
        try:
            self._authorize()
            parsed = urlparse(self.path)

            if parsed.path == "/health":
                self._json(HTTPStatus.OK, {"status": "ok", "version": VERSION})
                return

            if parsed.path == "/library":
                self._handle_library(parsed)
                return

            if parsed.path == "/search":
                self._handle_search(parsed)
                return

            if parsed.path.startswith("/video/") and parsed.path.endswith("/meta"):
                self._handle_meta(parsed.path)
                return

            if parsed.path.startswith("/video/") and parsed.path.endswith("/stream"):
                self._handle_stream(parsed.path, as_download=False)
                return

            if parsed.path.startswith("/video/") and parsed.path.endswith("/download"):
                self._handle_stream(parsed.path, as_download=True)
                return

            self._json(HTTPStatus.NOT_FOUND, {"error": "Not found"})
        except PermissionError as exc:
            self._json(HTTPStatus.UNAUTHORIZED, {"error": str(exc)})
        except ValueError as exc:
            self._json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
        except FileNotFoundError:
            self._json(HTTPStatus.NOT_FOUND, {"error": "Video not found"})
        except Exception as exc:  # pragma: no cover
            self._json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(exc)})

    def do_POST(self) -> None:
        self._method_not_allowed()

    def do_PUT(self) -> None:
        self._method_not_allowed()

    def do_PATCH(self) -> None:
        self._method_not_allowed()

    def do_DELETE(self) -> None:
        self._method_not_allowed()

    def log_message(self, format: str, *args) -> None:
        return

    def _method_not_allowed(self) -> None:
        self.send_response(HTTPStatus.METHOD_NOT_ALLOWED)
        self.send_header("Allow", "GET")
        self.end_headers()

    def _authorize(self) -> None:
        header = self.headers.get("Authorization", "")
        expected = f"Bearer {self.server.api_token}"
        if header != expected:
            raise PermissionError("Unauthorized")

    def _handle_library(self, parsed) -> None:
        query = parse_qs(parsed.query)
        rel_path = normalize_relative_path(query.get("path", [""])[0])
        folders, files = self.server.index.list_path(rel_path)
        self._json(HTTPStatus.OK, {"path": rel_path, "folders": folders, "files": files})

    def _handle_search(self, parsed) -> None:
        query = parse_qs(parsed.query)
        term = (query.get("q", [""])[0] or "").strip()
        if not term:
            raise ValueError("Missing q query")

        rel_path = query.get("path", [None])[0]
        files = self.server.index.search(term, rel_path)
        self._json(HTTPStatus.OK, {"files": files})

    def _handle_meta(self, path: str) -> None:
        video_id = path.split("/")[2]
        entry = self.server.index.get(video_id)
        if not entry:
            raise FileNotFoundError()
        self._json(HTTPStatus.OK, VideoIndex._to_wire(entry))

    def _handle_stream(self, path: str, as_download: bool) -> None:
        video_id = path.split("/")[2]
        entry = self.server.index.get(video_id)
        if not entry:
            raise FileNotFoundError()

        file_size = entry.size
        range_header = self.headers.get("Range")
        start = 0
        end = file_size - 1

        if range_header:
            if not range_header.startswith("bytes="):
                raise ValueError("Invalid range")
            spec = range_header.replace("bytes=", "", 1)
            left, _, right = spec.partition("-")
            if left:
                start = int(left)
            if right:
                end = int(right)
            end = min(end, file_size - 1)
            if start > end or start >= file_size:
                self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                self.send_header("Content-Range", f"bytes */{file_size}")
                self.end_headers()
                return

        content_length = (end - start) + 1
        status = HTTPStatus.PARTIAL_CONTENT if range_header else HTTPStatus.OK

        self.send_response(status)
        self.send_header("Content-Type", entry.mime_type)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(content_length))
        if range_header:
            self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
        if as_download:
            self.send_header("Content-Disposition", f'attachment; filename="{entry.filename}"')
        self.end_headers()

        with entry.absolute_path.open("rb") as handle:
            handle.seek(start)
            remaining = content_length
            while remaining > 0:
                chunk = handle.read(min(1024 * 256, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def _json(self, status: HTTPStatus, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class VaultServer(ThreadingHTTPServer):
    def __init__(self, server_address, api_token: str, index: VideoIndex):
        self.api_token = api_token
        self.index = index
        super().__init__(server_address, VaultHandler)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Vault video bridge")
    parser.add_argument("--root", required=True, help="Root directory containing videos")
    parser.add_argument("--token", required=True, help="Static API token")
    parser.add_argument("--host", default="100.64.0.1", help="Bind host (set to your Tailscale IP)")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument(
        "--allow-writable-root",
        action="store_true",
        help="Allow starting even when the process has write permission on --root (not recommended).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = Path(args.root)
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Invalid root: {root}")
    root = root.resolve()

    # Security default: refuse to run if this process can write into root.
    if not args.allow_writable_root and os.access(root, os.W_OK):
        raise SystemExit(
            "Refusing to start: root appears writable by this process. "
            "Mount/read-permission as read-only, or pass --allow-writable-root to override."
        )

    index = VideoIndex(root)
    index.rebuild()

    server = VaultServer((args.host, args.port), api_token=args.token, index=index)
    print(f"Vault bridge listening on http://{args.host}:{args.port}")
    print(f"Indexed videos: {len(index._by_id)}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
