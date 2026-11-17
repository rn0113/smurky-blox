#!/usr/bin/env python3
"""Clip live streams and VODs with Streamlink + ffmpeg.

Commands
  buffer  Keep the last few minutes of a live stream; press Enter to save a clip of what just happened.
  record  Record a live stream to a file (can wait for them to go live, and keep going every stream).
  vod     Download just one part of a past broadcast (a Twitch / Kick VOD, or YouTube with yt-dlp).
  cut     Cut a clip out of a file you already recorded.

Examples
  python clip.py buffer xqc                        # Enter = save last 60s, "30" = last 30s, q = quit
  python clip.py buffer "Kai Cenat" --vertical     # clips cropped to 9:16 for TikTok / Shorts / Reels
  python clip.py record ishowspeed --wait --forever
  python clip.py vod https://www.twitch.tv/videos/2300000000 --start 1:02:03 --length 45
  python clip.py cut recordings/xQc/2026-11-17_21-00-00_kick.mp4 --start 12:30 --end 13:10

A streamer can be a name or handle from streamers.json, any channel name, or a full URL.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime
from functools import lru_cache

HERE = os.path.dirname(os.path.abspath(__file__))
CLIPS_DIR = os.path.join(HERE, "clips")
RECORDINGS_DIR = os.path.join(HERE, "recordings")
PLATFORMS = ["twitch", "kick", "youtube"]
SEGMENT_SECONDS = 2
VERTICAL_FILTER = "crop=trunc(ih*9/16/2)*2:ih,scale=1080:1920,setsar=1"
UTF8_ENV = {**os.environ, "PYTHONIOENCODING": "utf-8"}


# ---------------------------------------------------------------- tools

@lru_cache(maxsize=None)
def streamlink_cmd():
    exe = shutil.which("streamlink")
    if exe:
        return (exe,)
    try:
        import streamlink_cli  # noqa: F401  (pip-installed but not on PATH)
        return (sys.executable, "-m", "streamlink_cli")
    except ImportError:
        sys.exit("Streamlink isn't installed.\n"
                 "  Windows: winget install streamlink.streamlink   (includes ffmpeg)\n"
                 "  macOS:   brew install streamlink\n"
                 "  Any OS:  pip install streamlink")


@lru_cache(maxsize=None)
def ffmpeg_cmd():
    exe = shutil.which("ffmpeg")
    if not exe and os.name == "nt":  # the Windows Streamlink installer ships its own ffmpeg
        for base in (os.environ.get("ProgramFiles"), os.environ.get("ProgramFiles(x86)")):
            path = os.path.join(base or "", "Streamlink", "ffmpeg", "ffmpeg.exe")
            if base and os.path.exists(path):
                exe = path
                break
    if not exe:
        sys.exit("ffmpeg isn't installed.\n"
                 "  Windows: winget install Gyan.FFmpeg\n"
                 "  macOS:   brew install ffmpeg\n"
                 "  Linux:   sudo apt install ffmpeg")
    return exe


@lru_cache(maxsize=None)
def duration_flag():
    """Streamlink 7+ renamed --hls-duration to --stream-segmented-duration."""
    help_text = subprocess.run([*streamlink_cmd(), "--help"], capture_output=True, text=True,
                               encoding="utf-8", errors="replace", env=UTF8_ENV).stdout
    return "--stream-segmented-duration" if "--stream-segmented-duration" in help_text else "--hls-duration"


# ---------------------------------------------------------------- time helpers

def parse_time(value):
    """'90', '1:30', '1:02:03', '1m30s', '2h' -> seconds."""
    s = str(value).strip().lower()
    m = re.fullmatch(r"(?:(\d+)h)?(?:(\d+)m)?(?:(\d+(?:\.\d+)?)s)?", s)
    if s and m and any(m.groups()):
        h, mi, sec = m.groups()
        return int(h or 0) * 3600 + int(mi or 0) * 60 + float(sec or 0)
    try:
        total = 0.0
        for part in s.split(":"):
            total = total * 60 + float(part)
        if s.count(":") <= 2 and total >= 0:
            return total
    except ValueError:
        pass
    raise argparse.ArgumentTypeError(f"can't read time {value!r} (try 90, 1:30, 1:02:03 or 1m30s)")


def hms(seconds):
    seconds = max(0.0, float(seconds))
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return f"{int(h):02d}:{int(m):02d}:{s:05.2f}"


def short(seconds):
    seconds = int(round(seconds))
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return f"{h}h{m:02d}m{s:02d}s" if h else f"{m}m{s:02d}s"


# ---------------------------------------------------------------- who / where

def load_streamers():
    try:
        with open(os.path.join(HERE, "streamers.json"), encoding="utf-8") as f:
            return json.load(f)["streamers"]
    except (OSError, ValueError, KeyError):
        return []


def channel_url(platform, handle):
    if platform == "twitch":
        return f"https://www.twitch.tv/{handle.lower()}"
    if platform == "kick":
        return f"https://kick.com/{handle.lower()}"
    if handle.startswith("UC") and len(handle) == 24:
        return f"https://www.youtube.com/channel/{handle}/live"
    return f"https://www.youtube.com/{handle if handle.startswith('@') else '@' + handle}/live"


def platform_of(url):
    u = url.lower()
    return "twitch" if "twitch.tv" in u else "kick" if "kick.com" in u else "youtube" if "youtu" in u else "stream"


def name_for_url(url):
    """Best-effort folder name for a URL: the streamer's name if we know them."""
    m = (re.search(r"(?:twitch\.tv|kick\.com)/([A-Za-z0-9_]+)", url)
         or re.search(r"youtube\.com/(@[A-Za-z0-9_.-]+)", url))
    handle = m.group(1) if m and m.group(1).lower() not in ("videos", "clip", "clips") else None
    if handle:
        for s in load_streamers():
            if any((s.get(p) or "").lower().lstrip("@") == handle.lower().lstrip("@") for p in PLATFORMS):
                return s["name"]
        return handle.lstrip("@")
    return platform_of(url)


def candidates(target, platform=None):
    """(display name, [(platform, url), ...]) for a name, handle or URL."""
    if "://" in target:
        return name_for_url(target), [(platform_of(target), target)]
    wanted = target.lower().lstrip("@")
    platforms = [platform] if platform else PLATFORMS
    for s in load_streamers():
        names = {s["name"].lower(), s["name"].lower().replace(" ", "")}
        names |= {s[p].lower().lstrip("@") for p in PLATFORMS if s.get(p)}
        if wanted in names:
            found = [(p, channel_url(p, s[p])) for p in platforms if s.get(p)]
            if not found:
                sys.exit(f"{s['name']} has no {platform} channel in streamers.json")
            return s["name"], found
    return target, [(p, channel_url(p, target)) for p in platforms]


def live_streams(url):
    """Ask Streamlink whether a URL has playable streams right now (no API keys needed)."""
    try:
        r = subprocess.run([*streamlink_cmd(), "--json", url], capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env=UTF8_ENV, timeout=90)
        return json.loads(r.stdout or "{}").get("streams") or {}
    except (subprocess.TimeoutExpired, ValueError):
        return {}


def find_live(target, platform=None, wait=False, poll=60):
    name, cands = candidates(target, platform)
    announced = False
    while True:
        for plat, url in cands:
            if not announced:
                print(f"checking {plat}: {url}")
            if live_streams(url):
                print(f"{name} is live on {plat}")
                return name, plat, url
        if not wait:
            sys.exit(f"{name} isn't live right now ({', '.join(p for p, _ in cands)}). "
                     "Add --wait to wait until they go live.")
        if not announced:
            print(f"{name} is offline - checking again every {poll}s (Ctrl+C to stop)")
        announced = True
        time.sleep(poll)


def out_path(folder, name, tag, ext="mp4"):
    folder = os.path.join(folder, re.sub(r"[^\w.-]+", "_", name).strip("_") or "stream")
    os.makedirs(folder, exist_ok=True)
    return os.path.join(folder, f"{datetime.now():%Y-%m-%d_%H-%M-%S}_{tag}.{ext}")


# ---------------------------------------------------------------- ffmpeg

def to_mp4(src, dst, vertical=False, start=None, length=None, exact=False):
    """Remux (fast, no quality loss) or re-encode (for --vertical / --exact) into an .mp4."""
    cmd = [ffmpeg_cmd(), "-hide_banner", "-loglevel", "error", "-y"]
    if start:
        cmd += ["-ss", f"{start:.3f}"]
    cmd += ["-i", src]
    if length:
        cmd += ["-t", f"{length:.3f}"]
    cmd += ["-map", "0:v?", "-map", "0:a?"]
    if vertical or exact:
        if vertical:
            cmd += ["-vf", VERTICAL_FILTER]
        cmd += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-c:a", "aac", "-b:a", "160k"]
    else:
        cmd += ["-c", "copy"]
    cmd += ["-movflags", "+faststart", dst]
    return subprocess.run(cmd).returncode == 0 and os.path.exists(dst)


def finish_ts(ts, vertical=False):
    """Turn a Streamlink .ts download into an .mp4 and remove the .ts."""
    if not os.path.exists(ts) or os.path.getsize(ts) == 0:
        print("nothing was downloaded")
        if os.path.exists(ts):
            os.remove(ts)
        return None
    mp4 = os.path.splitext(ts)[0] + ".mp4"
    if to_mp4(ts, mp4, vertical=vertical):
        os.remove(ts)
        print(f"saved {mp4}")
        return mp4
    print(f"couldn't convert to mp4 - the raw recording is kept at {ts}")
    return ts


# ---------------------------------------------------------------- buffer

class ReplayBuffer:
    """Streamlink -> ffmpeg segmenter writing 2-second .ts pieces into a temp folder.
    Old pieces are deleted so only the last `keep` seconds stay on disk."""

    def __init__(self, url, quality, keep):
        self.dir = tempfile.mkdtemp(prefix="clipbuffer_")
        self.list = os.path.join(self.dir, "segments.csv")
        self.keep = keep
        self.lock = threading.Lock()
        self.stopped = threading.Event()
        self.sl = subprocess.Popen([*streamlink_cmd(), url, quality, "--stdout", "--loglevel", "warning"],
                                   stdout=subprocess.PIPE)
        self.ff = subprocess.Popen([
            ffmpeg_cmd(), "-hide_banner", "-loglevel", "error", "-i", "pipe:0",
            "-map", "0:v?", "-map", "0:a?", "-c", "copy",
            "-f", "segment", "-segment_time", str(SEGMENT_SECONDS), "-segment_format", "mpegts",
            "-segment_list", self.list, "-segment_list_type", "csv",
            os.path.join(self.dir, "seg_%06d.ts")], stdin=self.sl.stdout)
        self.sl.stdout.close()  # ffmpeg owns the pipe now
        threading.Thread(target=self._janitor, daemon=True).start()
        threading.Thread(target=self._watch, daemon=True).start()

    def _finished(self):
        """[(path, duration)] of completed pieces that still exist, oldest first."""
        out = []
        try:
            with open(self.list, encoding="utf-8", errors="replace") as f:
                lines = f.read().splitlines()
        except OSError:
            return out
        for line in lines:
            parts = line.rsplit(",", 2)
            try:
                path = os.path.join(self.dir, os.path.basename(parts[0]))
                dur = float(parts[2]) - float(parts[1])
            except (ValueError, IndexError):
                continue
            if os.path.exists(path):
                out.append((path, dur))
        return out

    def _in_progress(self, finished):
        done = {p for p, _ in finished}
        pieces = sorted(f for f in os.listdir(self.dir) if f.startswith("seg_") and f.endswith(".ts"))
        last_done = max(done) if done else ""
        return [os.path.join(self.dir, f) for f in pieces
                if os.path.join(self.dir, f) not in done and os.path.join(self.dir, f) > last_done]

    def buffered_seconds(self):
        return sum(d for _, d in self._finished())

    def _janitor(self):
        while not self.stopped.wait(2):
            with self.lock:
                total = 0.0
                for path, dur in reversed(self._finished()):
                    total += dur
                    if total > self.keep + SEGMENT_SECONDS * 2:
                        try:
                            os.remove(path)
                        except OSError:
                            pass

    def _watch(self):
        self.ff.wait()
        if not self.stopped.is_set():
            print("\n[stream ended or disconnected - you can still save clips from what's buffered; q to quit]")

    def save(self, seconds, dst, vertical=False):
        with self.lock:
            finished = self._finished()
            pieces = self._in_progress(finished)  # what's being written right now (newest)
            total = 0.0
            for path, dur in reversed(finished):
                pieces.insert(0, path)
                total += dur
                if total >= seconds:
                    break
            if not pieces:
                return None
            joined = os.path.join(self.dir, "_clip.ts")
            with open(joined, "wb") as out:  # MPEG-TS pieces can simply be glued together
                for p in pieces:
                    with open(p, "rb") as f:
                        shutil.copyfileobj(f, out)
        ok = to_mp4(joined, dst, vertical=vertical)
        os.remove(joined)
        return dst if ok else None

    def close(self):
        self.stopped.set()
        # Stop Streamlink first; ffmpeg then sees the end of the stream and exits cleanly.
        for proc in (self.sl, self.ff):
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
        shutil.rmtree(self.dir, ignore_errors=True)


def cmd_buffer(a):
    if a.clip > a.keep:
        a.keep = a.clip
    name, plat, url = find_live(a.who, a.platform, a.wait)
    buf = ReplayBuffer(url, a.quality, a.keep)
    print(f"\nBuffering {name} on {plat} (keeps the last {short(a.keep)}).")
    print(f"  Enter      save the last {short(a.clip)}")
    print("  30 / 2m    save the last 30 seconds / 2 minutes")
    print("  q          quit\n")
    try:
        while True:
            line = input("> ").strip().lower()
            if line in ("q", "quit", "exit"):
                break
            seconds = a.clip
            if line:
                try:
                    seconds = parse_time(line)
                except argparse.ArgumentTypeError as e:
                    print(e)
                    continue
            have = buf.buffered_seconds()
            if have < 1:
                print("nothing buffered yet - give it a few seconds")
                continue
            if seconds > have + SEGMENT_SECONDS:
                print(f"only {short(have)} buffered so far - saving all of it")
            dst = out_path(a.out or CLIPS_DIR, name, f"{plat}_last{int(seconds)}s")
            print("saving..." if a.vertical else "", end="", flush=True)
            saved = buf.save(seconds, dst, a.vertical)
            print(f"\rsaved {saved}" if saved else "\rcouldn't save the clip")
    except (KeyboardInterrupt, EOFError):
        print()
    finally:
        buf.close()


# ---------------------------------------------------------------- record

def cmd_record(a):
    while True:
        name, plat, url = find_live(a.who, a.platform, wait=a.wait or a.forever)
        ts = out_path(a.out or RECORDINGS_DIR, name, plat, "ts")
        cmd = [*streamlink_cmd(), url, a.quality, "--output", ts, "--force", "--loglevel", "warning"]
        if a.length:
            cmd += [duration_flag(), hms(a.length)]
        if a.from_start:
            cmd += ["--hls-live-restart"]
        print(f"recording {name} ({plat}) -> {ts}\n(Ctrl+C to stop)")
        interrupted = False
        proc = subprocess.Popen(cmd)
        try:
            proc.wait()
        except KeyboardInterrupt:  # Streamlink got the Ctrl+C too and closes the file
            interrupted = True
            try:
                proc.wait(timeout=15)
            except (subprocess.TimeoutExpired, KeyboardInterrupt):
                proc.kill()
        finish_ts(ts, a.vertical)
        if interrupted or not a.forever:
            return
        print("stream ended - waiting for the next one")
        time.sleep(60)


# ---------------------------------------------------------------- vod

def clip_length(a):
    if a.length:
        return a.length
    if a.end is not None:
        if a.end <= a.start:
            sys.exit("--end has to be after --start")
        return a.end - a.start
    sys.exit("say how long the clip is with --length or --end")


def cmd_vod(a):
    length = clip_length(a)
    name = name_for_url(a.url)
    dst = out_path(a.out or CLIPS_DIR, name, f"vod_{short(a.start)}_{int(length)}s")

    if platform_of(a.url) == "youtube":  # Streamlink can't jump into YouTube VODs; yt-dlp can
        ytdlp = shutil.which("yt-dlp")
        if not ytdlp:
            sys.exit("For YouTube VODs install yt-dlp:  pip install yt-dlp\n"
                     "(Streamlink only handles YouTube *live* streams - use `buffer` or `record` for those.)")
        raw = dst[:-4] + "_raw.mp4"
        cmd = [ytdlp, "-f", "bv*[height<=1080]+ba/b", "--merge-output-format", "mp4",
               "--download-sections", f"*{hms(a.start)}-{hms(a.start + length)}",
               "--ffmpeg-location", ffmpeg_cmd(), "--force-overwrites", "-o", raw, a.url]
        if subprocess.run(cmd).returncode != 0 or not os.path.exists(raw):
            sys.exit("yt-dlp couldn't download that part")
        if a.vertical:
            to_mp4(raw, dst, vertical=True)
            os.remove(raw)
        else:
            os.replace(raw, dst)
        print(f"saved {dst}")
        return

    ts = dst[:-4] + ".ts"
    cmd = [*streamlink_cmd(), a.url, a.quality, "--output", ts, "--force", "--loglevel", "warning",
           "--hls-start-offset", hms(a.start), duration_flag(), hms(length)]
    print(f"downloading {short(length)} from {short(a.start)} into the VOD...")
    if subprocess.run(cmd).returncode != 0 and not os.path.exists(ts):
        sys.exit("Streamlink couldn't download that VOD (is the link right, and is the VOD still up?)")
    finish_ts(ts, a.vertical)


# ---------------------------------------------------------------- cut

def cmd_cut(a):
    if not os.path.exists(a.file):
        sys.exit(f"no such file: {a.file}")
    length = clip_length(a)
    dst = a.output or f"{os.path.splitext(a.file)[0]}_clip_{short(a.start)}-{short(a.start + length)}.mp4"
    if to_mp4(a.file, dst, vertical=a.vertical, start=a.start, length=length, exact=a.exact):
        print(f"saved {dst}")
    else:
        sys.exit("ffmpeg couldn't cut that file")


# ---------------------------------------------------------------- cli

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="command", required=True)

    def live_args(sp):
        sp.add_argument("who", help="streamer name/handle from streamers.json, a channel name, or a URL")
        sp.add_argument("--platform", choices=PLATFORMS,
                        help="only look on this platform (default: whichever one they're live on)")
        sp.add_argument("--wait", action="store_true", help="if they're offline, wait until they go live")

    def out_args(sp):
        sp.add_argument("--quality", default="best", help="e.g. best, 1080p60, 720p, 480p (default best)")
        sp.add_argument("--vertical", action="store_true", help="crop to 9:16 for TikTok/Shorts/Reels")
        sp.add_argument("--out", metavar="FOLDER", help="where to save (default: clips/ or recordings/)")

    sp = sub.add_parser("buffer", help="replay buffer: press Enter to clip what just happened")
    live_args(sp)
    out_args(sp)
    sp.add_argument("--clip", type=parse_time, default=60.0, help="default clip length (default 60s)")
    sp.add_argument("--keep", type=parse_time, default=300.0, help="how much to keep buffered (default 5m)")
    sp.set_defaults(func=cmd_buffer)

    sp = sub.add_parser("record", help="record a live stream")
    live_args(sp)
    out_args(sp)
    sp.add_argument("--length", type=parse_time, help="stop after this long, e.g. 30m (default: until it ends)")
    sp.add_argument("--from-start", action="store_true",
                    help="start from the beginning of the current broadcast (Twitch/YouTube, if available)")
    sp.add_argument("--forever", action="store_true", help="after a stream ends, wait and record the next one")
    sp.set_defaults(func=cmd_record)

    sp = sub.add_parser("vod", help="download one part of a past broadcast")
    sp.add_argument("url", help="VOD link, e.g. https://www.twitch.tv/videos/123456789")
    out_args(sp)
    sp.add_argument("--start", type=parse_time, required=True, help="where the clip starts, e.g. 1:02:03")
    sp.add_argument("--length", type=parse_time, help="clip length, e.g. 45 or 1m30s")
    sp.add_argument("--end", type=parse_time, help="or where the clip ends, e.g. 1:03:00")
    sp.set_defaults(func=cmd_vod)

    sp = sub.add_parser("cut", help="cut a clip out of a file you already have")
    sp.add_argument("file")
    sp.add_argument("--start", type=parse_time, required=True)
    sp.add_argument("--length", type=parse_time)
    sp.add_argument("--end", type=parse_time)
    sp.add_argument("--vertical", action="store_true", help="crop to 9:16 for TikTok/Shorts/Reels")
    sp.add_argument("--exact", action="store_true",
                    help="frame-exact cut (re-encodes; without it cuts snap to the nearest keyframe)")
    sp.add_argument("-o", "--output", help="output file (default: next to the input)")
    sp.set_defaults(func=cmd_cut)

    a = p.parse_args()
    a.func(a)


if __name__ == "__main__":
    main()
