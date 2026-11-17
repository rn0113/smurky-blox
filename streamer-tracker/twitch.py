#!/usr/bin/env python3
"""Twitch tracker (official Helix API).

Needs a free app from https://dev.twitch.tv/console/apps:
    TWITCH_CLIENT_ID=...    TWITCH_CLIENT_SECRET=...
(put them in .env next to this file or export them).
Usage: python twitch.py [--watch 60] [--csv twitch.csv] [--json] [--only xqc ibai]
"""
import os
from common import http_json, row, run_cli

API = "https://api.twitch.tv/helix"


def get_token():
    cid, secret = os.environ.get("TWITCH_CLIENT_ID"), os.environ.get("TWITCH_CLIENT_SECRET")
    if not cid or not secret:
        raise RuntimeError("Set TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET (see .env.example)")
    tok = http_json("https://id.twitch.tv/oauth2/token", data={
        "client_id": cid, "client_secret": secret, "grant_type": "client_credentials"})
    return cid, tok["access_token"]


def fetch(streamers):
    if not streamers:
        return []
    cid, token = get_token()
    headers = {"Client-Id": cid, "Authorization": f"Bearer {token}"}
    logins = [h.lower() for _, h in streamers]

    # Helix takes up to 100 logins per call; our list is small.
    users = {u["login"]: u for u in http_json(f"{API}/users", {"login": logins}, headers)["data"]}
    live = {s["user_login"].lower(): s for s in http_json(
        f"{API}/streams", {"user_login": logins, "first": 100}, headers)["data"]}

    rows = []
    for name, handle in streamers:
        login = handle.lower()
        url = f"https://twitch.tv/{login}"
        if login not in users:
            rows.append(row("twitch", name, login, url=url, error="channel not found"))
            continue
        s = live.get(login)
        if s:
            rows.append(row("twitch", name, login, live=True, viewers=s["viewer_count"],
                            title=s["title"], category=s["game_name"],
                            started_at=s["started_at"], url=url))
        else:
            rows.append(row("twitch", name, login, url=url))
    return rows


if __name__ == "__main__":
    run_cli("twitch", fetch)
