# Streamer Tracker

Checks whether these streamers are live, and how many people are watching, on **Twitch**, **Kick** and **YouTube**.
It can also clip and record their streams with Streamlink: see `clip.py` below.
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

## Clipping with Streamlink (`clip.py`)
Install **Streamlink** and **ffmpeg** first. No API keys are needed.
- Windows: `winget install streamlink.streamlink`. Streamlink's installer includes ffmpeg, and `clip.py` finds it automatically.
- macOS: `brew install streamlink ffmpeg`
- Linux: `pip install streamlink` and `sudo apt install ffmpeg`

```bash
# Replay buffer: keeps the last 5 minutes. Press Enter to save the last 60 seconds,
# type 30 or 2m to save a different length, and type q to quit.
python clip.py buffer xqc
python clip.py buffer "Kai Cenat" --vertical          # 9:16 clips for TikTok / Shorts / Reels
python clip.py buffer ibai --clip 30 --keep 10m --quality 720p60

# Record a whole stream. --wait waits for them to go live, and --forever records every stream.
python clip.py record ishowspeed --wait --forever
python clip.py record jasontheween --length 30m --from-start

# Download just one part of a past broadcast (VOD)
python clip.py vod https://www.twitch.tv/videos/2300000000 --start 1:02:03 --length 45
python clip.py vod https://kick.com/xqc/videos/<id> --start 10m --end 11m30s

# Cut a clip out of a recording (add --exact for a frame-exact cut, or --vertical for 9:16)
python clip.py cut recordings/xQc/2026-11-17_21-00-00_kick.mp4 --start 12:30 --end 13:10
```

- **Who:** use a name or handle from `streamers.json`, any channel name, or a full URL.
  The script checks Twitch, then Kick, then YouTube, and uses whichever one they're live on. `--platform kick` forces one.
- **Where files go:** clips are saved in `clips/<streamer>/` and recordings in `recordings/<streamer>/`, both as `.mp4`.
- **Buffer timing:** the replay buffer saves in roughly 2-second pieces, so a "last 60s" clip runs from 60 to about 62 seconds.
  It covers what the stream showed, which is a few seconds behind real time, the same as what you'd see in the player.
- **YouTube VODs:** these need `yt-dlp` (`pip install yt-dlp`), because Streamlink only handles YouTube live streams.
- **Twitch ads:** Streamlink skips Twitch ads automatically, which can leave a short gap in a recording.
- **Copyright:** only post clips in ways the streamer and the platform allow.

## Adding or fixing streamers
Edit `streamers.json`. Each entry takes any of `twitch`, `kick` and `youtube` (a YouTube `@handle` or a `UC…` channel ID).
**Double-check the handles.** They are best guesses, and streamers do change platforms
(for example, Speed is mostly on YouTube, and xQc and Marlon also stream on Kick).

## Notes
- YouTube: one full check costs about 3 quota units per channel, so the free 10,000 units a day covers checking every 2 minutes or so.
- Kick without keys uses kick.com's website API, and Cloudflare sometimes blocks that. If it does, add Kick API keys.
