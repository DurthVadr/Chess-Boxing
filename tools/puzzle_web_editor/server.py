#!/usr/bin/env python3
"""Local web server for puzzle HTML editor."""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
WEB_ROOT = Path(__file__).resolve().parent
DATA_ROOT = ROOT / "data"
PUZZLES_ROOT = DATA_ROOT / "puzzles"
OPPONENTS_PATH = DATA_ROOT / "opponents.json"

HOST = "127.0.0.1"
PORT = 8765

POOL_FILES = {
    "easy": PUZZLES_ROOT / "puzzles_easy.json",
    "medium": PUZZLES_ROOT / "puzzles_medium.json",
    "hard": PUZZLES_ROOT / "puzzles_hard.json",
}


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, payload) -> None:
    text = json.dumps(payload, indent=2, ensure_ascii=False)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")


def json_response(handler: BaseHTTPRequestHandler, status: int, payload) -> None:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def read_body_json(handler: BaseHTTPRequestHandler):
    raw_len = handler.headers.get("Content-Length", "0")
    length = int(raw_len)
    body = handler.rfile.read(length) if length > 0 else b"{}"
    return json.loads(body.decode("utf-8"))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("[puzzle-editor]", fmt % args)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/api/state":
            pools = {name: load_json(file_path) for name, file_path in POOL_FILES.items()}
            opponents = load_json(OPPONENTS_PATH)
            json_response(self, 200, {"pools": pools, "opponents": opponents})
            return

        if path.startswith("/api/pool/"):
            pool = path.split("/")[-1]
            if pool not in POOL_FILES:
                json_response(self, 404, {"error": f"Unknown pool: {pool}"})
                return
            json_response(self, 200, {"pool": pool, "puzzles": load_json(POOL_FILES[pool])})
            return

        if path == "/":
            self._serve_static("index.html", "text/html; charset=utf-8")
            return

        if path == "/app.js":
            self._serve_static("app.js", "application/javascript; charset=utf-8")
            return

        if path == "/styles.css":
            self._serve_static("styles.css", "text/css; charset=utf-8")
            return

        json_response(self, 404, {"error": "Not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith("/api/pool/") and path.endswith("/save"):
            parts = path.strip("/").split("/")
            if len(parts) != 4:
                json_response(self, 404, {"error": "Invalid endpoint"})
                return
            pool = parts[2]
            if pool not in POOL_FILES:
                json_response(self, 404, {"error": f"Unknown pool: {pool}"})
                return

            try:
                body = read_body_json(self)
            except Exception as exc:
                json_response(self, 400, {"error": f"Invalid JSON body: {exc}"})
                return

            puzzles = body.get("puzzles")
            if not isinstance(puzzles, list):
                json_response(self, 400, {"error": "Body must include puzzles: Array"})
                return

            save_json(POOL_FILES[pool], puzzles)
            json_response(self, 200, {"ok": True, "pool": pool, "count": len(puzzles)})
            return

        json_response(self, 404, {"error": "Not found"})

    def _serve_static(self, filename: str, mime: str) -> None:
        path = WEB_ROOT / filename
        if not path.exists():
            json_response(self, 404, {"error": f"Missing {filename}"})
            return
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Puzzle editor running on http://{HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
