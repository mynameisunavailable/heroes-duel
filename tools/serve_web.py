"""Serve the Web export on the local network, for testing on a phone.

    python tools/serve_web.py

Export first:

    godot --headless --path . --export-release Web build/web/index.html

Then open the printed http://<your-pc-ip>:8060/ address in the phone's browser, with the
phone on the same Wi-Fi. Windows will likely ask to allow Python through the firewall:
allow it on Private networks only.

This is a convenience for checking layout, thumb reach and multitouch early. It is not a
substitute for a real iOS build: browser chrome changes the safe area, the vibration API
differs from native haptics, and single-threaded WebGL performance is not representative.
"""

from __future__ import annotations

import argparse
import http.server
import socket
from functools import partial
from pathlib import Path

DEFAULT_PORT = 8060
DEFAULT_DIR = Path(__file__).resolve().parent.parent / "build" / "web"


class Handler(http.server.SimpleHTTPRequestHandler):
    """Adds the headers a Godot web build wants, and disables caching.

    The cross-origin isolation headers only take effect in a secure context, so over
    plain HTTP they are harmless; they are sent so the same server also works when it is
    reached over HTTPS or from localhost.
    """

    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"  {self.address_string()} {fmt % args}")


def lan_addresses() -> list[str]:
    """Best-effort list of this machine's LAN IPv4 addresses."""
    found: list[str] = []
    try:
        # Opening a UDP socket to an off-machine address reveals the outbound interface
        # without sending anything.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(("10.255.255.255", 1))
            found.append(probe.getsockname()[0])
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            address = info[4][0]
            if not address.startswith("127.") and address not in found:
                found.append(address)
    except OSError:
        pass
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--dir", type=Path, default=DEFAULT_DIR)
    args = parser.parse_args()

    root: Path = args.dir
    if not (root / "index.html").exists():
        print(f"No export found in {root}.")
        print("Run: godot --headless --path . --export-release Web build/web/index.html")
        return 1

    handler = partial(Handler, directory=str(root))
    with http.server.ThreadingHTTPServer(("0.0.0.0", args.port), handler) as server:
        print(f"Serving {root} on port {args.port}. Press Ctrl+C to stop.\n")
        print("  On this PC:   http://localhost:%d/" % args.port)
        for address in lan_addresses():
            print(f"  On your phone: http://{address}:{args.port}/")
        print()
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
