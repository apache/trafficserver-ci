#!/usr/bin/env python3
"""GitHub webhook receiver for the ATS CI Git mirrors."""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlsplit


EXPECTED_REPOS = {
    "apache/trafficserver": "trafficserver",
    "apache/trafficserver-ci": "trafficserver-ci",
}


def getenv_int(name: str, default: int) -> int:
    value = os.environ.get(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        raise SystemExit(f"{name} must be an integer")


WEBHOOK_HOST = os.environ.get("WEBHOOK_HOST", "127.0.0.1")
WEBHOOK_PORT = getenv_int("WEBHOOK_PORT", 9419)
WEBHOOK_PATH = os.environ.get("WEBHOOK_PATH", "/github-mirror-webhook")
WEBHOOK_SECRET = os.environ.get("GITHUB_WEBHOOK_SECRET")
UPDATE_MIRROR = os.environ.get(
    "UPDATE_MIRROR",
    "/opt/trafficserver-ci/github-mirror/bin/update-mirror.sh",
)
MIRROR_ROOT = os.environ.get("MIRROR_ROOT", "/home/mirror")
MAX_BODY_BYTES = getenv_int("MAX_BODY_BYTES", 1024 * 1024)
UPDATE_TIMEOUT_SECONDS = getenv_int("UPDATE_TIMEOUT_SECONDS", 600)


def log(message: str) -> None:
    print(f"github-mirror-webhook: {message}", file=sys.stderr, flush=True)


def verify_signature(body: bytes, header_value: str | None) -> bool:
    if not WEBHOOK_SECRET or WEBHOOK_SECRET == "CHANGE_ME":
        log("GITHUB_WEBHOOK_SECRET is not configured")
        return False
    if not header_value or not header_value.startswith("sha256="):
        return False
    expected = "sha256=" + hmac.new(
        WEBHOOK_SECRET.encode("utf-8"),
        body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, header_value)


def run_update(*args: str) -> str:
    command = [UPDATE_MIRROR, *args]
    env = os.environ.copy()
    env["MIRROR_ROOT"] = MIRROR_ROOT

    start = time.monotonic()
    completed = subprocess.run(
        command,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=UPDATE_TIMEOUT_SECONDS,
        check=False,
    )
    elapsed = time.monotonic() - start
    output = completed.stdout.strip()
    if output:
        for line in output.splitlines():
            log(line)

    if completed.returncode != 0:
        raise RuntimeError(
            f"{' '.join(command)} failed with exit {completed.returncode}"
        )

    return f"updated via {' '.join(command)} in {elapsed:.1f}s"


def repo_name(payload: dict[str, Any]) -> str:
    repository = payload.get("repository")
    if not isinstance(repository, dict):
        raise ValueError("payload missing repository object")

    full_name = repository.get("full_name")
    if not isinstance(full_name, str):
        raise ValueError("payload missing repository.full_name")
    if full_name not in EXPECTED_REPOS:
        raise PermissionError(f"unexpected repository: {full_name}")
    return full_name


def handle_event(event: str, payload: dict[str, Any]) -> tuple[int, str]:
    full_name = repo_name(payload)
    mirror_repo = EXPECTED_REPOS[full_name]

    if event == "ping":
        return 200, f"pong for {full_name}\n"

    if event == "push":
        result = run_update(mirror_repo, "--heads-tags")
        return 200, result + "\n"

    if event == "pull_request":
        if mirror_repo != "trafficserver":
            raise ValueError("pull_request events are only accepted for apache/trafficserver")

        number = payload.get("number")
        if not isinstance(number, int):
            raise ValueError("payload missing integer pull request number")

        action = payload.get("action")
        if action == "closed":
            result = run_update("trafficserver", "--delete-pr", str(number), "--heads-tags")
        else:
            result = run_update("trafficserver", "--pr", str(number))
        return 200, result + "\n"

    raise ValueError(f"unsupported event: {event}")


class WebhookHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def send_text(self, status: int, body: str) -> None:
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        path = urlsplit(self.path).path
        if path != WEBHOOK_PATH:
            self.send_text(404, "not found\n")
            return

        event = self.headers.get("X-GitHub-Event", "")
        delivery = self.headers.get("X-GitHub-Delivery", "unknown-delivery")

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_text(400, "invalid content length\n")
            return

        if length <= 0:
            self.send_text(400, "empty request body\n")
            return
        if length > MAX_BODY_BYTES:
            self.send_text(413, "request body too large\n")
            return

        body = self.rfile.read(length)
        if not verify_signature(body, self.headers.get("X-Hub-Signature-256")):
            log(f"rejected delivery={delivery} event={event}: bad signature")
            self.send_text(401, "bad signature\n")
            return

        try:
            payload = json.loads(body.decode("utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("payload root is not an object")
            status, response = handle_event(event, payload)
            log(f"accepted delivery={delivery} event={event}: {response.strip()}")
            self.send_text(status, response)
        except PermissionError as exc:
            log(f"rejected delivery={delivery} event={event}: {exc}")
            self.send_text(403, f"{exc}\n")
        except (ValueError, json.JSONDecodeError) as exc:
            log(f"bad delivery={delivery} event={event}: {exc}")
            self.send_text(400, f"{exc}\n")
        except subprocess.TimeoutExpired:
            log(f"timed out delivery={delivery} event={event}")
            self.send_text(504, "mirror update timed out\n")
        except Exception as exc:  # Keep GitHub delivery diagnostics explicit.
            log(f"failed delivery={delivery} event={event}: {exc}")
            self.send_text(500, f"{exc}\n")

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        path = urlsplit(self.path).path
        if path == "/healthz":
            self.send_text(200, "ok\n")
        else:
            self.send_text(405, "method not allowed\n")

    def log_message(self, fmt: str, *args: Any) -> None:
        log(fmt % args)


def main() -> int:
    if not WEBHOOK_SECRET or WEBHOOK_SECRET == "CHANGE_ME":
        log("refusing to start without GITHUB_WEBHOOK_SECRET")
        return 1

    server = ThreadingHTTPServer((WEBHOOK_HOST, WEBHOOK_PORT), WebhookHandler)
    log(f"listening on http://{WEBHOOK_HOST}:{WEBHOOK_PORT}{WEBHOOK_PATH}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("shutting down")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
