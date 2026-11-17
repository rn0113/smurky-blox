#!/usr/bin/env python3
"""Kick tracker.

Uses Kick's official public API if KICK_CLIENT_ID / KICK_CLIENT_SECRET are set
(create an app at https://kick.com/settings/developer). Without them it falls back
to kick.com's website API, which works but is sometimes blocked by Cloudflare.
Usage: python kick.py [--watch 60] [--csv kick.csv] [--json] [--only xqc]
"""
import os
from common import http_json, row, run_cli

OFFICIAL = "https://api.kick.com/public/v1"


def official_token():
    cid, secret = os.environ.get("KICK_CLIENT_ID"), os.environ.get("KICK_CLIENT_SECRET")
    if not cid or not secret:
        return None
    tok = http_json("https://id.kick.com/oauth/token", data={
        "client_id": cid, "client_secret": secret, "grant_type": "client_credentials"})
    return tok["access_token"]


def fetch_official(streamers, token):
    slugs = [h.lower() for _, h in streamers]
    data = http_json(f"{OFFICIAL}/channels", {"slug": slugs},
                     {"Authorization": f"Bearer {token}"})["data"]
    by_slug = {c["slug"].lower(): c for c in data}
    rows = []
    for name, handle in streamers:
        slug = handle.lower()
        url = f"https://kick.com/{slug}"
        c = by_slug.get(slug)
        if not c:
            rows.append(row("kick", name, slug, url=url, error="channel not found"))
            continue
        s = c.get("stream") or {}
        live = bool(s.get("is_live"))
        rows.append(row("kick", name, slug, live=live, url=url,
                        viewers=s.get("viewer_count", 0) if live else "",
                        title=c.get("stream_title", "") if live else "",
                        category=(c.get("category") or {}).get("name", "") if live else "",
                        started_at=s.get("start_time", "") if live else ""))
    return rows


def fetch_web(streamers):
    rows = []
    for name, handle in streamers:
        slug = handle.lower()
        url = f"https://kick.com/{slug}"
        try:
            c = http_json(f"https://kick.com/api/v2/channels/{slug}")
        except RuntimeError as e:
            rows.append(row("kick", name, slug, url=url, error=str(e)))
            continue
        ls = c.get("livestream") or {}
        cats = ls.get("categories") or [{}]
        rows.append(row("kick", name, slug, live=bool(ls.get("is_live")), url=url,
                        viewers=ls.get("viewer_count", "") if ls else "",
                        title=ls.get("session_title", ""),
                        category=cats[0].get("name", ""),
                        started_at=(ls.get("start_time") or "").replace(" ", "T"),
                        followers=c.get("followers_count") or c.get("followersCount")))
    return rows


def fetch(streamers):
    if not streamers:
        return []
    token = official_token()
    return fetch_official(streamers, token) if token else fetch_web(streamers)


if __name__ == "__main__":
    run_cli("kick", fetch)
