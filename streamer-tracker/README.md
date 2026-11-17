# Streamer Tracker

Checks whether these streamers are live, and how many people are watching, on **Twitch**, **Kick** and **YouTube**.
It needs Python 3.8 or newer and nothing else to install. The list of streamers is in `streamers.json`.

| Script | Platform | What you need |
|---|---|---|
| `twitch.py` | Twitch | `TWITCH_CLIENT_ID` and `TWITCH_CLIENT_SECRET`. Register a free app at https://dev.twitch.tv/console/apps and set the redirect URL to `http://localhost`. |
| `kick.py` | Kick | Nothing. Optionally add `KICK_CLIENT_ID` and `KICK_CLIENT_SECRET` from https://kick.com/settings/developer to use Kick's official API. |
| `youtube.py` | YouTube | `YOUTUBE_API_KEY`. In Google Cloud Console, turn on YouTube Data API v3 and create an API key. |
| `track_all.py` | All three | Any of the above. A platform without keys is skipped. |

## Setup
```bash
cd streamer-tracker
cp .env.example .env      # then put your keys in .env
```

## Usage
```bash
python twitch.py                          # check once and print a table
python kick.py --watch 60                 # check every 60s and alert when someone goes live or offline
python youtube.py --only @IShowSpeed      # check only some streamers (use their name or handle)
python track_all.py --watch 90 --csv log.csv   # all platforms, saving every check to a CSV file
python track_all.py --json                # JSON output, for piping into other tools
```

Each check shows: whether they're live, viewer count, how long they've been live, stream title, category or game,
and the follower or subscriber count where the platform gives it out (Kick and YouTube).

## Adding or fixing streamers
Edit `streamers.json`. Each entry takes any of `twitch`, `kick` and `youtube` (a YouTube `@handle` or a `UC…` channel ID).
**Double-check the handles.** They are best guesses, and streamers do change platforms
(for example, Speed is mostly on YouTube, and xQc and Marlon also stream on Kick).

## Notes
- YouTube: one full check costs about 3 quota units per channel, so the free 10,000 units a day covers checking every 2 minutes or so.
- Kick without keys uses kick.com's website API, and Cloudflare sometimes blocks that. If it does, add Kick API keys.
