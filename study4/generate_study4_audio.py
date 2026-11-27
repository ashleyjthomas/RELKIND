#!/usr/bin/env python3
"""
Generate the STUDY 4 ("loves vs. likes") audio for Twizzle Town.

Study 4 keeps Study 3's People-generic speeches AND the original character
intros (reused unchanged) but swaps the ROLE framing: one speaker LOVES the
target and one LIKES the target. This script generates every clip whose text
mentions the roles, plus the two attention-check clips, OVERWRITING copies
in this folder:

  11 x <key>_frame.mp3    "One of them loves {T}, and one of them likes {T}.
                           You'll have to figure out which is which!"
  11 x <key>_prefix.mp3   "Remember, one of them loves {T} and one of them
                           likes {T}. Do you think it's like this?"
  44 x <key>_opt_{A,B}_{1,2}.mp3
                          _A_1 "{pA} loves {T},"   _A_2 "and {pB} likes {T}."
                          _B_1 "{pA} likes {T},"   _B_2 "and {pB} loves {T}."
                          (both cards read LEFT-to-RIGHT: pA first, then pB)
   1 x loves_probe.mp3    "One last question! Who loves someone: their boss,
                           their best friend, or both of them?"
   1 x loves_more.mp3     "Who loves them more?" (asked only after "both")
   1 x memcheck_intro.mp3 "Wait! Listen to this one more time."
   1 x memcheck_who.mp3   "Who said that?"

Reused unchanged: <key>_intro (original years/equal-time version),
all <key>_{hmm|yes}_{ind|group}.mp3 People speeches, do_you_think.mp3,
or_like_this.mp3, why_question.mp3, stars, etc.  (_likeA/_likeB are no
longer played.)

USAGE (from this folder):
  ELEVENLABS_API_KEY="sk_..." python3 generate_study4_audio.py
Optionally pass filename substrings to regenerate only matches, e.g.:
  python3 generate_study4_audio.py _frame _prefix
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

JOBS = [
    ("loves_probe.mp3",
     "One last question! Who loves someone: their boss, "
     "their best friend, or both of them?"),
    ("loves_more.mp3", "Who loves them more?"),
    ("memcheck_intro.mp3", "Wait! Listen to this one more time."),
    ("memcheck_who.mp3",   "Who said that?"),
    ("memcheck_correction.mp3", "Good try! It was actually this one who said that!"),
    ("memcheck_tryagain.mp3", "Not quite! Let's try again."),
    ("memcheck_right.mp3",    "That's right!"),
    # "Who loves them more?" follow-up: options named in on-screen order,
    # each button bounces while it is named (order randomized, so both
    # plain and "or" variants exist for each option).
    ("probeopt_boss.mp3",    "Their boss?"),
    ("probeopt_or_boss.mp3", "Or their boss?"),
    ("probeopt_bf.mp3",      "Their best friend?"),
    ("probeopt_or_bf.mp3",   "Or their best friend?"),
    # First probe ("Who loves someone?") also names each option with a
    # bounce, reusing probeopt_boss / probeopt_bf plus these two:
    ("lovesq_intro.mp3", "One last question! Who loves someone?"),
    ("lovesq_both.mp3",  "Or both of them?"),
]
for key, T, pA, pB in TARGETS:
    JOBS += [
      (f"{key}_frame.mp3",
       f"One of them loves {T}, and one of them likes {T}. "
       f"You'll have to figure out which is which!"),
      (f"{key}_prefix.mp3",
       f"Remember, one of them loves {T} and one of them likes {T}. "
       f"Do you think it's like this?"),
      (f"{key}_opt_A_1.mp3", f"{pA} loves {T},"),
      (f"{key}_opt_A_2.mp3", f"and {pB} likes {T}."),
      (f"{key}_opt_B_1.mp3", f"{pA} likes {T},"),
      (f"{key}_opt_B_2.mp3", f"and {pB} loves {T}."),
    ]

API_KEY = os.environ.get("ELEVENLABS_API_KEY")
if not API_KEY:
    sys.exit('Set ELEVENLABS_API_KEY, e.g.\n  ELEVENLABS_API_KEY="sk_..." python3 generate_study4_audio.py')
URL = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
HEADERS = {"xi-api-key": API_KEY, "Content-Type": "application/json"}
# Optional filter: pass substrings to only generate matching files, e.g.
#   python3 generate_study4_audio.py _intro _frame
pats = [p for p in sys.argv[1:] if not p.startswith("-")]
if pats:
    JOBS = [(f, t) for f, t in JOBS if any(p in f for p in pats)]
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
