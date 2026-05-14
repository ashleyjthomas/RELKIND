#!/usr/bin/env python3
"""
Twizzle Town v10 — generate the new MP3s for the v10 game update.

Generates 14 files into the same directory as this script:
  - 12 × {key}_intro.mp3  (new relationship-setup story text)
  - mid_video.mp3         (missing from repo; needed for mid-game break)
  - end_video.mp3         (new; needed for end-screen video)

USAGE:
  1.  Set your ElevenLabs API key in your shell:
          export ELEVENLABS_API_KEY="sk_..."
      OR paste it into the API_KEY line below.
  2.  cd into this folder:
          cd "/Users/ashleythomas/Dropbox (Personal)/Mac (2)/Desktop/RELKIND"
  3.  Run:
          python3 generate_v10_audio.py

  No `pip install` needed — uses the `requests` module that ships with Mac Python.
"""
import os, sys, json
try:
    import requests
except ImportError:
    print("`requests` is missing. Install with: pip3 install requests")
    sys.exit(1)

# ─────────────────────────────────────────────────────────────
#  CONFIG
# ─────────────────────────────────────────────────────────────
API_KEY  = os.environ.get("ELEVENLABS_API_KEY", "").strip() or "PASTE_KEY_HERE"
VOICE_ID = "CBHdTdZwkV4jYoCyMV1B"
MODEL    = "eleven_turbo_v2_5"
VOICE_SETTINGS = {
    "stability":         0.55,
    "similarity_boost":  0.85,
    "style":             0.0,
    "use_speaker_boost": True,
}

if API_KEY == "PASTE_KEY_HERE":
    print("ERROR: set ELEVENLABS_API_KEY env var, or edit API_KEY at the top of this script.")
    sys.exit(1)

# ─────────────────────────────────────────────────────────────
#  TRIAL DATA — must match TRIALS in index.html
# ─────────────────────────────────────────────────────────────
TRIALS = {
    "rowan":  ("Rowan",  "Emery",  "Jules"),
    "casey":  ("Casey",  "River",  "Morgan"),
    "taylor": ("Taylor", "Finley", "Robin"),
    "alex":   ("Alex",   "Quinn",  "Drew"),
    "jordan": ("Jordan", "Skyler", "Reese"),
    "riley":  ("Riley",  "Ash",    "Charlie"),
    "sam":    ("Sam",    "Nova",   "Finn"),
    "theo":   ("Theo",   "Cleo",   "Moss"),
    "sage":   ("Sage",   "Juno",   "Reed"),
    "blake":  ("Blake",  "Zara",   "Bryn"),
    "wren":   ("Wren",   "Lumi",   "Flint"),
    "arlo":   ("Arlo",   "Cora",   "Beau"),
}

def intro_text(tgt, pA, pB):
    return (
        f"Now you'll meet {tgt}. "
        f"{tgt} has known {pA} and {pB} for several years "
        f"and has spent equal time with both of them. "
        f"{tgt} is a Wug, {pA} is a Flurp, and {pB} is a Zazzo."
    )

JOBS = []
for key, (tgt, pA, pB) in TRIALS.items():
    JOBS.append((f"{key}_intro.mp3", intro_text(tgt, pA, pB)))
JOBS.append((
    "mid_video.mp3",
    "Great job! You still have some more questions, but first, watch this funny video!",
))
JOBS.append((
    "end_video.mp3",
    "You did it! Thank you so much for visiting Twizzle Town. "
    "You were amazing! Watch this fun video as a treat!",
))

# ─────────────────────────────────────────────────────────────
#  GENERATE
# ─────────────────────────────────────────────────────────────
URL = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
HEADERS = {
    "xi-api-key":   API_KEY,
    "accept":       "audio/mpeg",
    "content-type": "application/json",
}

here = os.path.dirname(os.path.abspath(__file__))
os.chdir(here)

ok = 0
fail = 0
for filename, text in JOBS:
    print(f"  {filename:<24}  ", end="", flush=True)
    body = {"text": text, "model_id": MODEL, "voice_settings": VOICE_SETTINGS}
    try:
        r = requests.post(URL, headers=HEADERS, json=body, timeout=90)
    except Exception as e:
        print(f"NETWORK ERROR: {e}")
        fail += 1
        continue
    if r.status_code == 200:
        with open(filename, "wb") as f:
            f.write(r.content)
        print(f"OK  ({len(r.content):>7,d} bytes)")
        ok += 1
    else:
        print(f"FAILED [{r.status_code}]: {r.text[:200]}")
        fail += 1

print(f"\nDone. {ok} succeeded, {fail} failed.")
if fail:
    sys.exit(1)
