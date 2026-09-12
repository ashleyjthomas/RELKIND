#!/usr/bin/env python3
"""
Generate STUDY 2 audio for Twizzle Town.

Files generated (61 total):
  12 <target>_frame.mp3                                 (character intro: "One of the
                                                         people that X knows is X's
                                                         best friend and one is X's
                                                         boss.  You'll have to figure
                                                         out which is which!")
  12 <target>_prefix.mp3                                (choice-screen prefix:
                                                         "Remember, one is X's best
                                                         friend and one is X's boss.
                                                         Do you think it's like this?")
   1 or_like_this.mp3                                   (generic connector)
  48 <target>_opt_{A,B}_{1,2}.mp3                       (option halves, no "In this
                                                         one," prefix — the frame is
                                                         provided by prefix.mp3):
                                                           _A_1 = "[pA] is X's best friend,"
                                                           _A_2 = "and [pB] is X's boss."
                                                           _B_1 = "[pB] is X's best friend,"
                                                           _B_2 = "and [pA] is X's boss."

Reused from Study 1 (no regeneration needed):
  - <target>_intro / _likeA / _likeB / _action / _ask / _reread
  - <target>_{ep}_{ind|group}.mp3 speech clips
  - star_*, mid_video, welcome, setup, etc.
NOT used in Study 2 anymore (safe to leave; no harm):
  - <target>_q_close.mp3, <target>_q_boss.mp3   (asked-role questions)

Reused from Study 1 (no regeneration needed):
  - <target>_q_close.mp3   ("Who is [target]'s best friend?")
  - <target>_q_boss.mp3    ("Who is [target]'s boss?")
  - all <target>_{ep}_{ind|group}.mp3 speech clips
  - <target>_intro / _likeA / _likeB / _action / _ask / _reread
  - star_*, mid_video, welcome, setup, etc.

USAGE:
  cd "/Users/ashleythomas/Dropbox (Personal)/Mac (2)/Documents/GitHub/RELKIND/study2"
  ELEVENLABS_API_KEY="sk_..." python3 generate_study2_audio.py
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

# Trial config MUST match TRIALS in study2/index.html
# (12 targets; pA/pB are the two peers who will speak in the trial)
TARGETS = [
    # (key, target_name,  personA,   personB)
    ("rowan",  "Rowan",   "Emery",   "Jules"),
    ("casey",  "Casey",   "River",   "Morgan"),
    ("taylor", "Taylor",  "Finley",  "Robin"),
    ("alex",   "Alex",    "Quinn",   "Drew"),
    ("jordan", "Jordan",  "Skyler",  "Reese"),
    ("riley",  "Riley",   "Ash",     "Charlie"),
    ("sam",    "Sam",     "Nova",    "Finn"),
    ("theo",   "Theo",    "Cleo",    "Moss"),
    ("sage",   "Sage",    "Juno",    "Reed"),
    ("blake",  "Blake",   "Zara",    "Bryn"),
    ("wren",   "Wren",    "Lumi",    "Flint"),
    ("arlo",   "Arlo",    "Cora",    "Beau"),
]

JOBS = []

# ── (1) Per-target joint frame (12 files) ──────────────────────
# Spoken alongside the character intro so kids hear the framing right when
# they meet each new target.
for key, tgt, pA, pB in TARGETS:
    JOBS.append((
        f"{key}_frame.mp3",
        f"One of the people that {tgt} knows is {tgt}'s best friend and "
        f"one is {tgt}'s boss. You'll have to figure out which is which!"
    ))

# ── (2) Per-target choice-screen prefix (12 files) ─────────────
# Played at the top of the option-card screen, before the two option
# descriptions. Symmetric — never mentions a specific asked role.
for key, tgt, pA, pB in TARGETS:
    JOBS.append((
        f"{key}_prefix.mp3",
        f"Remember, one is {tgt}'s best friend and one is {tgt}'s boss. "
        f"Do you think it's like this?"
    ))

# ── (3) Generic connector (1 file) ─────────────────────────────
JOBS.append(("or_like_this.mp3", "Or like this?"))
JOBS.append(("do_you_think.mp3", "Do you think it's like this?"))
JOBS.append(("why_question.mp3", "Why do you think that?"))

# ── (4) Per-target option read-aloud, split into 2 clips per option ─
# Splitting the sentence lets the UI highlight the character portrait
# being named as each clip plays.  No "In this one," prefix — the
# per-target `_prefix.mp3` above and the generic `or_like_this.mp3`
# provide the "in this one / or like this" framing.
#   Option A: pA in best-friend slot, pB in boss slot
#     opt_A_1.mp3  ->  "{pA} is {tgt}'s best friend,"
#     opt_A_2.mp3  ->  "and {pB} is {tgt}'s boss."
#   Option B: roles flipped, but characters SPOKEN in the same
#   left-to-right order as displayed (pA first, then pB):
#     opt_B_1.mp3  ->  "{pA} is {tgt}'s boss,"
#     opt_B_2.mp3  ->  "and {pB} is {tgt}'s best friend."
for key, tgt, pA, pB in TARGETS:
    JOBS.append((f"{key}_opt_A_1.mp3",
                 f"{pA} is {tgt}'s best friend,"))
    JOBS.append((f"{key}_opt_A_2.mp3",
                 f"and {pB} is {tgt}'s boss."))
    JOBS.append((f"{key}_opt_B_1.mp3",
                 f"{pA} is {tgt}'s boss,"))
    JOBS.append((f"{key}_opt_B_2.mp3",
                 f"and {pB} is {tgt}'s best friend."))

# ── Run ─────────────────────────────────────────────────────────
URL = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
HEADERS = {
    "xi-api-key":   API_KEY,
    "accept":       "audio/mpeg",
    "content-type": "application/json",
}
os.chdir(os.path.dirname(os.path.abspath(__file__)))

print(f"Generating {len(JOBS)} audio files with voice {VOICE_ID} ({MODEL})...\n")
ok = fail = skipped = 0
for filename, text in JOBS:
    print(f"  {filename:<28}  ", end="", flush=True)
    if os.path.exists(filename):
        print("EXISTS (skipping — delete to regenerate)"); skipped += 1; continue
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

print(f"\nDone. {ok} generated, {skipped} skipped (already exist), {fail} failed.")
if fail: sys.exit(1)
