import functools
import http.server
import mimetypes
import os

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "builds", "web")
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("text/javascript", ".js")

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("[HTTP] " + (fmt % args), flush=True)

if __name__ == "__main__":
    handler = functools.partial(Handler, directory=ROOT)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 8060), handler)
    print("serving", ROOT, "at http://127.0.0.1:8060", flush=True)
    srv.serve_forever()
