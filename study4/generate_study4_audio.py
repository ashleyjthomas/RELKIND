#!/usr/bin/env python3
"""
Generate the STUDY 4 ("loves vs. just met") audio for Twizzle Town.

Study 4 keeps Study 3's People-generic speeches (reused unchanged) but swaps
the ROLE framing: instead of best friend / boss, one speaker LOVES the target
and one JUST MET the target.  This script regenerates every clip whose text
mentions the roles, OVERWRITING the copies in this folder:

  11 x <key>_frame.mp3    "One of the people that {T} knows loves {T}, and one
                           of them just met {T}. You'll have to figure out
                           which is which!"
  11 x <key>_prefix.mp3   "Remember, one of them loves {T} and one of them
                           just met {T}. Do you think it's like this?"
  44 x <key>_opt_{A,B}_{1,2}.mp3
                          _A_1 "{pA} loves {T},"     _A_2 "and {pB} just met {T}."
                          _B_1 "{pB} loves {T},"     _B_2 "and {pA} just met {T}."
   1 x probe_question.mp3 "One last question! Who knows more about what someone
                           likes to do: their boss, or their best friend?"
Reused unchanged: all <key>_{hmm|yes}_{ind|group}.mp3 People speeches,
do_you_think.mp3, or_like_this.mp3, why_question.mp3, intros, stars, etc.

USAGE (from this folder):
  ELEVENLABS_API_KEY="sk_..." python3 generate_study4_audio.py
Then:  python3 equalize_volume.py
"""
import os, sys, time, requests

VOICE_ID = "CBHdTdZwkV4jYoCyMV1B"       # same narrator as Studies 1-3
MODEL    = "eleven_turbo_v2_5"
VOICE_SETTINGS = {"stability": 0.55, "similarity_boost": 0.85,
                  "style": 0.0, "use_speaker_boost": True}

# (key, target, personA, personB) — must match TRIALS in index.html
TARGETS = [
    ("rowan",  "Rowan",  "Emery",  "Jules"),
    ("casey",  "Casey",  "River",  "Morgan"),
    ("taylor", "Taylor", "Finley", "Robin"),
    ("jordan", "Jordan", "Skyler", "Reese"),
    ("riley",  "Riley",  "Ash",    "Charlie"),
    ("sam",    "Sam",    "Nova",   "Finn"),
    ("theo",   "Theo",   "Cleo",   "Moss"),
    ("sage",   "Sage",   "Juno",   "Reed"),
    ("blake",  "Blake",  "Zara",   "Bryn"),
    ("wren",   "Wren",   "Lumi",   "Flint"),
    ("arlo",   "Arlo",   "Cora",   "Beau"),
]

JOBS = [("probe_question.mp3",
         "One last question! Who knows more about what someone likes to do: "
         "their boss, or their best friend?")]
for key, T, pA, pB in TARGETS:
    JOBS += [
      (f"{key}_frame.mp3",
       f"One of the people that {T} knows loves {T}, and one of them just met "
       f"{T}. You'll have to figure out which is which!"),
      (f"{key}_prefix.mp3",
       f"Remember, one of them loves {T} and one of them just met {T}. "
       f"Do you think it's like this?"),
      (f"{key}_opt_A_1.mp3", f"{pA} loves {T},"),
      (f"{key}_opt_A_2.mp3", f"and {pB} just met {T}."),
      (f"{key}_opt_B_1.mp3", f"{pB} loves {T},"),
      (f"{key}_opt_B_2.mp3", f"and {pA} just met {T}."),
    ]

API_KEY = os.environ.get("ELEVENLABS_API_KEY")
if not API_KEY:
    sys.exit('Set ELEVENLABS_API_KEY, e.g.\n  ELEVENLABS_API_KEY="sk_..." python3 generate_study4_audio.py')
URL = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
HEADERS = {"xi-api-key": API_KEY, "Content-Type": "application/json"}
print(f"Generating {len(JOBS)} clips with voice {VOICE_ID} ({MODEL})...\n")
done = fail = 0
for fname, text in JOBS:
    r = requests.post(URL, headers=HEADERS, json={
        "text": text, "model_id": MODEL, "voice_settings": VOICE_SETTINGS,
        "output_format": "mp3_44100_128"})
    if r.status_code == 200:
        open(fname, "wb").write(r.content); done += 1
        print(f"  ok  {fname}")
    else:
        fail += 1; print(f"  FAIL {fname}: {r.status_code} {r.text[:100]}")
    time.sleep(0.4)
print(f"\n{done} generated, {fail} failed.")
print("Now run:  python3 equalize_volume.py")
