"""Shared helpers for the streamer trackers (standard library only)."""
import csv
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (streamer-tracker)"

# Every tracker returns a list of dicts with these keys.
FIELDS = ["checked_at", "platform", "name", "handle", "live", "viewers",
          "title", "category", "started_at", "followers", "url", "error"]


def load_env(path=os.path.join(HERE, ".env")):
    """Load KEY=VALUE lines from .env into os.environ (doesn't override)."""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def load_streamers(platform, path=os.path.join(HERE, "streamers.json")):
    """Return [(display name, handle)] for everyone who has an account on `platform`."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return [(s["name"], s[platform]) for s in data["streamers"] if s.get(platform)]


def http_json(url, params=None, headers=None, data=None, retries=3):
    if params:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params, doseq=True)
    body = urllib.parse.urlencode(data).encode() if isinstance(data, dict) else data
    h = {"User-Agent": UA, "Accept": "application/json"}
    h.update(headers or {})
    for attempt in range(retries):
        req = urllib.request.Request(url, data=body, headers=h)
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                time.sleep(int(e.headers.get("Retry-After") or 2 ** attempt))
                continue
            detail = e.read().decode("utf-8", "replace")[:300]
            raise RuntimeError(f"HTTP {e.code} from {url.split('?')[0]}: {detail}") from None
        except urllib.error.URLError as e:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f"Network error for {url.split('?')[0]}: {e.reason}") from None


def now_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def row(platform, name, handle, **kw):
    r = {k: "" for k in FIELDS}
    r.update(checked_at=now_iso(), platform=platform, name=name, handle=handle, live=False)
    r.update({k: v for k, v in kw.items() if v is not None})
    return r


def uptime(started_at):
    if not started_at:
        return ""
    try:
        start = datetime.fromisoformat(started_at.replace("Z", "+00:00"))
        if start.tzinfo is None:
            start = start.replace(tzinfo=timezone.utc)
        mins = int((datetime.now(timezone.utc) - start).total_seconds() // 60)
        return f"{mins // 60}h{mins % 60:02d}m"
    except ValueError:
        return ""


def print_table(rows):
    rows = sorted(rows, key=lambda r: (not r["live"], -(r["viewers"] or 0), r["name"].lower()))
    print(f"{'PLATFORM':8} {'STREAMER':14} {'STATUS':7} {'VIEWERS':>9} {'UPTIME':>7}  {'FOLLOWERS':>11}  TITLE / CATEGORY")
    print("-" * 110)
    for r in rows:
        if r["error"]:
            status, extra = "ERROR", r["error"][:70]
        else:
            status = "LIVE" if r["live"] else "offline"
            extra = " | ".join(x for x in (r["title"][:55] if r["title"] else "", r["category"]) if x)
        viewers = f"{r['viewers']:,}" if r["live"] and r["viewers"] != "" else ""
        followers = f"{r['followers']:,}" if isinstance(r["followers"], int) else ""
        print(f"{r['platform']:8} {r['name'][:14]:14} {status:7} {viewers:>9} {uptime(r['started_at']) if r['live'] else '':>7}  {followers:>11}  {extra}")


def append_csv(rows, path):
    new = not os.path.exists(path)
    with open(path, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        if new:
            w.writeheader()
        w.writerows(rows)


def run_cli(platform, fetch):
    """Shared CLI for each platform script: one-shot, --watch, --csv, --json."""
    import argparse
    p = argparse.ArgumentParser(description=f"Track streamers on {platform}.")
    p.add_argument("--watch", type=int, metavar="SECONDS", help="re-check every N seconds")
    p.add_argument("--csv", metavar="FILE", help="append every check to a CSV file")
    p.add_argument("--json", action="store_true", help="print JSON instead of a table")
    p.add_argument("--only", nargs="+", metavar="NAME", help="only track these streamers")
    args = p.parse_args()
    load_env()
    watch(lambda: fetch(filter_only(load_streamers(platform), args.only)), args)


def filter_only(streamers, only):
    if not only:
        return streamers
    want = {o.lower() for o in only}
    return [(n, h) for n, h in streamers if n.lower() in want or h.lower().lstrip("@") in want]


def watch(get_rows, args):
    was_live = {}
    while True:
        try:
            rows = get_rows()
        except RuntimeError as e:
            print(f"error: {e}", file=sys.stderr)
            if not args.watch:
                sys.exit(1)
            rows = []
        if args.json:
            print(json.dumps(rows, indent=2, ensure_ascii=False))
        else:
            if args.watch:
                print(f"\n=== {now_iso()} ===")
            print_table(rows)
        for r in rows:  # go-live / go-offline alerts
            key = (r["platform"], r["handle"])
            if r["error"]:
                continue
            if key in was_live and was_live[key] != r["live"]:
                msg = "WENT LIVE" if r["live"] else "went offline"
                print(f"\a>>> {r['name']} {msg} on {r['platform']}  {r['url']}", flush=True)
            was_live[key] = r["live"]
        if args.csv and rows:
            append_csv(rows, args.csv)
        if not args.watch:
            break
        time.sleep(args.watch)
