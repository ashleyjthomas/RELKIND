#!/usr/bin/env python3
"""
Generate end_exit.mp3 — the parent-instructions narration that plays
on the end screen after audio_end_parent.mp3 and end_video.mp3.

(audio_end_parent.mp3 is Ashley's own custom recording, converted from
.m4a — this script does NOT regenerate it.)

USAGE:
  cd "/Users/ashleythomas/Dropbox (Personal)/Mac (2)/Documents/GitHub/RELKIND"
  ELEVENLABS_API_KEY="sk_..." python3 scripts/generate_end_parent_audio.py
"""
import os, sys, requests

API_KEY  = os.environ.get("ELEVENLABS_API_KEY", "").strip() or "PASTE_KEY_HERE"
VOICE_ID = "CBHdTdZwkV4jYoCyMV1B"
MODEL    = "eleven_turbo_v2_5"
VOICE_SETTINGS = {
    "stability": 0.55, "similarity_boost": 0.85,
    "style": 0.0, "use_speaker_boost": True,
}

if API_KEY == "PASTE_KEY_HERE":
    print("ERROR: set ELEVENLABS_API_KEY env var.")
    sys.exit(1)

JOBS = [
    ("end_exit.mp3",
     "Parents, when you're ready, press the Escape key to leave fullscreen, "
     "and then click back into the C H S tab to continue."),
]

URL = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
HEADERS = {
    "xi-api-key":   API_KEY,
    "accept":       "audio/mpeg",
    "content-type": "application/json",
}

# Write outputs into the repo root (parent of scripts/)
here = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.dirname(here)
os.chdir(out_dir)

for filename, text in JOBS:
    print(f"  {filename:<26}  ", end="", flush=True)
    r = requests.post(URL, headers=HEADERS, json={
        "text": text, "model_id": MODEL, "voice_settings": VOICE_SETTINGS,
    }, timeout=60)
    if r.status_code == 200:
        with open(filename, "wb") as f:
            f.write(r.content)
        print(f"OK ({len(r.content):,d} bytes)")
    else:
        print(f"FAILED [{r.status_code}]: {r.text[:200]}")

print("Done.")
