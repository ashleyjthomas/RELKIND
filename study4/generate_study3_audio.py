#!/usr/bin/env python3
"""
Generate the STUDY 3 ("People" generic) audio for Twizzle Town.

Study 3 is identical to Study 2 except the GROUP-level speech says
    "Hmm, People must like to X."  /  "Yes, People like to X."
instead of "Wugs ...".  Everything else (intros, options, frames, prefix,
individual-level speech) is reused unchanged from the copied Study 2 assets.

This script therefore regenerates ONLY the 22 group-speech clips
(11 characters x hmm/yes), OVERWRITING the copies in this folder:
    <key>_hmm_group.mp3   <key>_yes_group.mp3

USAGE (from this folder):
  ELEVENLABS_API_KEY="sk_..." python3 generate_study3_audio.py
Then equalize loudness:
  python3 equalize_volume.py
"""
import os, sys, time, requests

VOICE_ID = "CBHdTdZwkV4jYoCyMV1B"          # same narrator as Studies 1-2
MODEL    = "eleven_turbo_v2_5"
VOICE_SETTINGS = {
    "stability": 0.55, "similarity_boost": 0.85,
    "style": 0.0, "use_speaker_boost": True,
}

# character key -> group behavior phrase (must match act.g in index.html)
BEHAVIORS = {
    "rowan":  "play with bugs",
    "casey":  "stay up in the middle of the night",
    "taylor": "climb tall buildings",
    "jordan": "whisper when they talk",
    "riley":  "eat flowers",
    "sam":    "pick up rocks and put them in their pocket",
    "theo":   "walk backwards",
    "sage":   "talk to plants",
    "blake":  "pile up pinecones into a tall tower",
    "wren":   "spin around before sitting down",
    "arlo":   "sniff things before touching them",
}

JOBS = []
for key, beh in BEHAVIORS.items():
    JOBS.append((f"{key}_hmm_group.mp3", f"Hmm, People must like to {beh}."))
    JOBS.append((f"{key}_yes_group.mp3", f"Yes, People like to {beh}."))

API_KEY = os.environ.get("ELEVENLABS_API_KEY")
if not API_KEY:
    sys.exit("Set ELEVENLABS_API_KEY, e.g.\n  ELEVENLABS_API_KEY=\"sk_...\" python3 generate_study3_audio.py")

URL = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
HEADERS = {"xi-api-key": API_KEY, "Content-Type": "application/json"}
print(f"Generating {len(JOBS)} group-speech files with voice {VOICE_ID} ({MODEL})...\n")
done = skipped = 0
for fname, text in JOBS:
    r = requests.post(URL, headers=HEADERS, json={
        "text": text, "model_id": MODEL, "voice_settings": VOICE_SETTINGS,
        "output_format": "mp3_44100_128"})
    if r.status_code == 200:
        open(fname, "wb").write(r.content)
        done += 1; print(f"  ok  {fname}  «{text}»")
    else:
        skipped += 1; print(f"  FAIL {fname}: {r.status_code} {r.text[:120]}")
    time.sleep(0.4)
print(f"\n{done} generated, {skipped} failed.")
print("Now run:  python3 equalize_volume.py   (re-levels ALL clips incl. these)")
