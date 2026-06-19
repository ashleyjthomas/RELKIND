#!/usr/bin/env python3
"""
Regenerate Closer-block audio with the new "best friend" wording (v11.7).

Generates 13 files:
  - block_close.mp3        (block-level intro)
  - 12 × {key}_q_close.mp3  (per-character question prompts)

USAGE:
  cd "/Users/ashleythomas/Dropbox (Personal)/Mac (2)/Documents/GitHub/RELKIND"
  ELEVENLABS_API_KEY="sk_..." python3 scripts/generate_bestfriend_audio.py
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

# 12 trial-character targets (must match TRIALS in index.html)
TARGETS = {
    "rowan":  "Rowan",
    "casey":  "Casey",
    "taylor": "Taylor",
    "alex":   "Alex",
    "jordan": "Jordan",
    "riley":  "Riley",
    "sam":    "Sam",
    "theo":   "Theo",
    "sage":   "Sage",
    "blake":  "Blake",
    "wren":   "Wren",
    "arlo":   "Arlo",
}

JOBS = []

# Block-level intro audio
JOBS.append((
    "block_close.mp3",
    "After each story, I will ask: Who is this character's best friend? "
    "That means the person they love more, tell more secrets to, "
    "and give more hugs to."
))

# Per-character question prompts
for key, name in TARGETS.items():
    JOBS.append((
        f"{key}_q_close.mp3",
        f"Who is {name}'s best friend?"
    ))

URL = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
HEADERS = {
    "xi-api-key":   API_KEY,
    "accept":       "audio/mpeg",
    "content-type": "application/json",
}

# Write outputs to repo root (parent of scripts/)
here    = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.dirname(here)
os.chdir(out_dir)

ok = fail = 0
for filename, text in JOBS:
    print(f"  {filename:<24}  ", end="", flush=True)
    try:
        r = requests.post(URL, headers=HEADERS, json={
            "text": text, "model_id": MODEL, "voice_settings": VOICE_SETTINGS,
        }, timeout=60)
    except Exception as e:
        print(f"NETWORK ERROR: {e}"); fail += 1; continue
    if r.status_code == 200:
        with open(filename, "wb") as f: f.write(r.content)
        print(f"OK ({len(r.content):,d} bytes)"); ok += 1
    else:
        print(f"FAILED [{r.status_code}]: {r.text[:200]}"); fail += 1

print(f"\nDone. {ok} succeeded, {fail} failed.")
if fail: sys.exit(1)
