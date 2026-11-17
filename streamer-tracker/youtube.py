#!/usr/bin/env python3
"""YouTube tracker (YouTube Data API v3).

Needs an API key (Google Cloud console -> enable "YouTube Data API v3" -> Credentials):
    YOUTUBE_API_KEY=...
Live detection avoids the expensive search endpoint: it reads each channel's latest
uploads and checks which one is currently live. A full check costs about
3 quota units per channel, so the free 10,000/day quota covers checking every ~minute.
Usage: python youtube.py [--watch 120] [--csv youtube.csv] [--json] [--only @IShowSpeed]
"""
import os
from common import http_json, row, run_cli

API = "https://www.googleapis.com/youtube/v3"
_channel_cache = {}  # handle -> channel info, so --watch doesn't re-resolve handles


def resolve(handle, key):
    if handle not in _channel_cache:
        params = {"part": "snippet,statistics,contentDetails", "key": key}
        if handle.startswith("UC") and len(handle) == 24:
            params["id"] = handle
        else:
            params["forHandle"] = handle if handle.startswith("@") else "@" + handle
        items = http_json(f"{API}/channels", params).get("items") or []
        _channel_cache[handle] = items[0] if items else None
    return _channel_cache[handle]


def fetch(streamers):
    if not streamers:
        return []
    key = os.environ.get("YOUTUBE_API_KEY")
    if not key:
        raise RuntimeError("Set YOUTUBE_API_KEY (see .env.example)")

    channels, rows = {}, []
    for name, handle in streamers:
        try:
            ch = resolve(handle, key)
        except RuntimeError as e:
            rows.append(row("youtube", name, handle, error=str(e)))
            continue
        if not ch:
            rows.append(row("youtube", name, handle, error="channel not found"))
            continue
        channels[handle] = ch

    # Latest 5 uploads per channel (1 unit each); live streams show up here.
    candidates = {}
    for handle, ch in channels.items():
        uploads = ch["contentDetails"]["relatedPlaylists"]["uploads"]
        try:
            items = http_json(f"{API}/playlistItems", {
                "part": "contentDetails", "playlistId": uploads, "maxResults": 5, "key": key})["items"]
        except RuntimeError:
            items = []
        for it in items:
            candidates[it["contentDetails"]["videoId"]] = handle

    # One batched videos call (50 ids per unit) to find what's live right now.
    live_by_handle = {}
    ids = list(candidates)
    for i in range(0, len(ids), 50):
        vids = http_json(f"{API}/videos", {
            "part": "snippet,liveStreamingDetails", "id": ",".join(ids[i:i + 50]), "key": key})["items"]
        for v in vids:
            lsd = v.get("liveStreamingDetails") or {}
            if v["snippet"].get("liveBroadcastContent") == "live" and not lsd.get("actualEndTime"):
                live_by_handle.setdefault(candidates[v["id"]], v)

    for name, handle in streamers:
        ch = channels.get(handle)
        if not ch:
            continue
        stats = ch.get("statistics", {})
        subs = None if stats.get("hiddenSubscriberCount") else int(stats.get("subscriberCount", 0))
        v = live_by_handle.get(handle)
        if v:
            lsd = v["liveStreamingDetails"]
            rows.append(row("youtube", name, handle, live=True,
                            viewers=int(lsd.get("concurrentViewers", 0)),
                            title=v["snippet"]["title"], started_at=lsd.get("actualStartTime", ""),
                            followers=subs, url=f"https://youtube.com/watch?v={v['id']}"))
        else:
            rows.append(row("youtube", name, handle, followers=subs,
                            url=f"https://youtube.com/{handle}"))
    return rows


if __name__ == "__main__":
    run_cli("youtube", fetch)
