#!/usr/bin/env python3
import socket
import sys
import time


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: wait_for_port.py HOST PORT", file=sys.stderr)
        return 2

    host = sys.argv[1]
    port = int(sys.argv[2])
    deadline = time.time() + 30
    last_error = None

    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1):
                return 0
        except OSError as exc:
            last_error = exc
            time.sleep(0.5)

    print(f"timed out waiting for {host}:{port}: {last_error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
