"""Background voice for Game Text Speaker.

Streams Microsoft Edge "Natural" voices (via edge-tts) straight to the speakers
with ffplay, so no Edge window is needed. The AHK script talks to it through a
file: it writes the text to request.txt, an empty request means "stop".

Usage: pythonw tts_helper.py --dir <folder> --voice <voice> --rate +0% --parent <pid>
"""
import argparse
import asyncio
import ctypes
import os
import shutil
import subprocess
import sys
import time

import aiohttp
import edge_tts

CREATE_NO_WINDOW = 0x08000000


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


class Reader:
    def __init__(self, args):
        self.args = args
        self.req = os.path.join(args.dir, "request.txt")
        self.work = os.path.join(args.dir, "request.working")
        self.logfile = os.path.join(args.dir, "tts_log.txt")
        self.ffplay = args.ffplay or shutil.which("ffplay") or "ffplay"
        self.task = None
        self.player = None

    def log(self, msg):
        try:
            with open(self.logfile, "a", encoding="utf-8") as f:
                f.write(time.strftime("%H:%M:%S ") + msg + "\n")
        except OSError:
            pass

    def start_player(self):
        return subprocess.Popen(
            [self.ffplay, "-nodisp", "-autoexit", "-loglevel", "error",
             "-f", "mp3", "-probesize", "32", "-analyzeduration", "0",
             "-fflags", "nobuffer", "-i", "pipe:0"],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=CREATE_NO_WINDOW)

    async def stop(self):
        if self.task and not self.task.done():
            self.task.cancel()
            try:
                await self.task
            except BaseException:
                pass
        self.task = None
        if self.player and self.player.poll() is None:
            self.player.kill()
        self.player = None

    async def speak(self, text):
        t0 = time.perf_counter()
        # Start ffplay while we connect, so its startup overlaps the network wait.
        self.player = player = self.start_player()
        sent = 0
        for attempt in range(3):
            try:
                # ThreadedResolver: aiodns can fail to find DNS servers on Windows.
                conn = aiohttp.TCPConnector(resolver=aiohttp.ThreadedResolver())
                comm = edge_tts.Communicate(text, self.args.voice, rate=self.args.rate,
                                            connector=conn, connect_timeout=4, receive_timeout=15)
                async for chunk in comm.stream():
                    if chunk["type"] != "audio":
                        continue
                    if sent == 0:
                        self.log(f"first audio after {(time.perf_counter() - t0) * 1000:.0f} ms"
                                 + (f" (attempt {attempt + 1})" if attempt else ""))
                    try:
                        player.stdin.write(chunk["data"])
                        player.stdin.flush()
                    except (OSError, ValueError):  # player closed / killed
                        return
                    sent += len(chunk["data"])
                break
            except asyncio.CancelledError:
                raise
            except Exception as e:
                self.log(f"attempt {attempt + 1} failed: {e!r}")
                # Retrying after audio already played would repeat the start.
                if sent:
                    break
        try:
            player.stdin.close()
        except OSError:
            pass

    def take_request(self):
        try:
            os.replace(self.req, self.work)  # atomic: a newer request can't be lost
            with open(self.work, encoding="utf-8-sig") as f:
                text = f.read()
            os.remove(self.work)
            return text
        except FileNotFoundError:
            return None
        except OSError:
            return None  # AHK still writing; try on the next tick

    async def run(self):
        self.log(f"started, voice {self.args.voice}, ffplay {self.ffplay}")
        ticks = 0
        while True:
            text = self.take_request()
            if text is not None:
                await self.stop()
                text = text.strip()
                if text:
                    self.task = asyncio.create_task(self.speak(text))
            await asyncio.sleep(0.015)
            ticks += 1
            if ticks % 60 == 0 and not parent_alive(self.args.parent):
                await self.stop()
                return


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", default=os.path.dirname(os.path.abspath(__file__)))
    p.add_argument("--voice", default="en-US-AvaMultilingualNeural")
    p.add_argument("--rate", default="+0%")
    p.add_argument("--ffplay", default="")
    p.add_argument("--parent", type=int, default=0)
    args = p.parse_args()
    # The Selector loop avoids Proactor connect hangs seen on some Windows setups.
    asyncio.run(Reader(args).run(), loop_factory=asyncio.SelectorEventLoop)


if __name__ == "__main__":
    sys.exit(main())
