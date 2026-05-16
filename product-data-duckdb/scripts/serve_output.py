#!/usr/bin/env python3
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HOST = "127.0.0.1"
PORT = 8000
DIRECTORY = Path("output")


def main() -> None:
    if not DIRECTORY.exists():
        raise SystemExit("output directory does not exist. Run make run first.")

    handler = partial(SimpleHTTPRequestHandler, directory=str(DIRECTORY))
    httpd = ThreadingHTTPServer((HOST, PORT), handler)
    print(f"Serving {DIRECTORY} at http://{HOST}:{PORT}/")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
