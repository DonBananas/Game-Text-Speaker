"""Local bridge between Game Text Speaker and Edge's own voices.

Serves speech.html on 127.0.0.1 and hands it the text the AHK script writes to
request.txt (an empty request means "stop"). The page speaks it with Edge's
built-in Natural voices, so Edge never has to be reloaded or brought forward.

Usage: pythonw speech_server.py --dir <folder> --port 8765 --parent <pid>
"""
import argparse
import ctypes
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


def parent_alive(pid):
    if not pid:
        return True
    h = ctypes.windll.kernel32.OpenProcess(0x1000, False, pid)  # QUERY_LIMITED_INFORMATION
    if not h:
        return False
    code = ctypes.c_ulong()
    ctypes.windll.kernel32.GetExitCodeProcess(h, ctypes.byref(code))
    ctypes.windll.kernel32.CloseHandle(h)
    return code.value == 259  # STILL_ACTIVE


class State:
    def __init__(self, folder):
        self.folder = folder
        self.cond = threading.Condition()
        self.id = 0
        self.text = ""
        self.t = 0.0
        self.session = str(time.time_ns())

    def log(self, msg):
        try:
            with open(os.path.join(self.folder, "tts_log.txt"), "a", encoding="utf-8") as f:
                f.write(time.strftime("%H:%M:%S ") + msg + "\n")
        except OSError:
            pass

    def post(self, text):
        with self.cond:
            self.id += 1
            self.text = text
            self.t = time.time() * 1000
            self.cond.notify_all()


def watch_requests(state, parent):
    req = os.path.join(state.folder, "request.txt")
    work = os.path.join(state.folder, "request.working")
    ticks = 0
    while True:
        try:
            os.replace(req, work)  # atomic: a newer request can't be lost
            with open(work, encoding="utf-8-sig") as f:
                state.post(f.read().strip())
            os.remove(work)
        except OSError:
            pass  # no request yet, or AHK still writing
        time.sleep(0.01)
        ticks += 1
        if ticks % 100 == 0 and not parent_alive(parent):
            os._exit(0)


def make_handler(state, page_path):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send(self, code, body=b"", ctype="application/json"):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            url = urlparse(self.path)
            q = parse_qs(url.query)
            if url.path == "/":
                with open(page_path, "rb") as f:
                    self.send(200, f.read(), "text/html; charset=utf-8")
            elif url.path == "/next":
                after = int(q.get("after", ["-1"])[0])
                with state.cond:
                    if after < 0:  # page just loaded: don't replay old text
                        msg = {"id": state.id, "text": None}
                    elif state.cond.wait_for(lambda: state.id > after, timeout=20):
                        msg = {"id": state.id, "text": state.text, "t": state.t}
                    else:
                        msg = {"id": state.id, "text": None}
                msg["session"] = state.session
                self.send(200, json.dumps(msg).encode())
            elif url.path == "/log":
                state.log(q.get("m", [""])[0][:500])
                if q.get("ready"):
                    open(os.path.join(state.folder, "voice_ready.flag"), "w").close()
                self.send(204)
            else:
                self.send(404)

    return Handler


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", default=os.path.dirname(os.path.abspath(__file__)))
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("--parent", type=int, default=0)
    args = p.parse_args()
    state = State(args.dir)
    page = os.path.join(os.path.dirname(os.path.abspath(__file__)), "speech.html")
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(state, page))
    except OSError as e:
        state.log(f"server could not start on port {args.port}: {e!r}")
        return
    server.daemon_threads = True
    state.log(f"server started on port {args.port}")
    threading.Thread(target=watch_requests, args=(state, args.parent), daemon=True).start()
    server.serve_forever()


if __name__ == "__main__":
    main()
