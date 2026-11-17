#!/usr/bin/env python3
"""Check every platform at once and print one combined table.
Platforms without credentials are skipped with a note (Kick works without any).
Usage: python track_all.py [--watch 90] [--csv all.csv] [--json] [--only xqc "Kai Cenat"]
"""
import argparse
import sys
from concurrent.futures import ThreadPoolExecutor

import kick
import twitch
import youtube
from common import filter_only, load_env, load_streamers, watch

TRACKERS = {"twitch": twitch.fetch, "kick": kick.fetch, "youtube": youtube.fetch}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--watch", type=int, metavar="SECONDS")
    p.add_argument("--csv", metavar="FILE")
    p.add_argument("--json", action="store_true")
    p.add_argument("--only", nargs="+", metavar="NAME")
    p.add_argument("--platforms", nargs="+", choices=list(TRACKERS), default=list(TRACKERS))
    args = p.parse_args()
    load_env()

    def run_one(platform):
        try:
            return TRACKERS[platform](filter_only(load_streamers(platform), args.only))
        except RuntimeError as e:
            print(f"[{platform}] skipped: {e}", file=sys.stderr)
            return []

    def get_rows():
        with ThreadPoolExecutor(len(args.platforms)) as pool:
            return [r for rows in pool.map(run_one, args.platforms) for r in rows]

    watch(get_rows, args)


if __name__ == "__main__":
    main()
