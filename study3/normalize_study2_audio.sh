#!/usr/bin/env bash
# ==================================================================
#  normalize_study2_audio.sh
#
#  Loudness-normalise every .mp3 in RELKIND/study2/ so the new
#  Study 2 clips (frame, opt_*_{1,2}) sit at the same perceived
#  loudness as the Study 1 audio bed (~ -18 dBFS peak / -16 LUFS
#  integrated).  Uses ffmpeg's `loudnorm` filter (EBU R128 spec)
#  in a single-pass mode.
#
#  USAGE:
#    brew install ffmpeg          # if you don't have it
#    cd "/Users/ashleythomas/Dropbox (Personal)/Mac (2)/Documents/GitHub/RELKIND/study2"
#    bash normalize_study2_audio.sh
#
#  The script writes normalized files to a tmp/ subdir first, then
#  moves them into place, so a failure mid-run doesn't leave you with
#  half-processed audio.  Originals in tmp/originals/ can be inspected
#  or restored if you dislike the result.
#
#  Idempotent: files that were already normalised (marked by the
#  presence of tmp/originals/<name>.mp3) are skipped on re-run.
# ==================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg not found.  Install with: brew install ffmpeg" >&2
  exit 1
fi

mkdir -p tmp/originals tmp/normalized

# ── Loudness target (matches Study 1) ────────────────────────────
# -16 LUFS integrated with -1.5 dB true peak headroom is a common
# child-friendly target; adjust if you want it louder/quieter.
I_TARGET="-16"
TP_TARGET="-1.5"
LRA_TARGET="11"

count_total=0
count_done=0
count_skipped=0

for f in *.mp3; do
  count_total=$((count_total + 1))
  base="${f%.mp3}"

  # Skip if we've already backed up the original -- means it's been
  # normalized in a previous run.  Delete tmp/originals/<name>.mp3 to
  # force re-normalization.
  if [[ -f "tmp/originals/${f}" ]]; then
    count_skipped=$((count_skipped + 1))
    continue
  fi

  printf "  %-32s  " "${f}"
  # Single-pass loudnorm (fast; accurate enough for TTS clips)
  if ffmpeg -y -hide_banner -loglevel error -i "${f}" \
      -af "loudnorm=I=${I_TARGET}:TP=${TP_TARGET}:LRA=${LRA_TARGET}" \
      -ar 44100 -b:a 128k "tmp/normalized/${f}" </dev/null; then
    # Back up original before overwriting
    mv "${f}" "tmp/originals/${f}"
    mv "tmp/normalized/${f}" "${f}"
    count_done=$((count_done + 1))
    printf "OK\n"
  else
    printf "FAILED (kept original)\n"
  fi
done

echo
echo "Normalized ${count_done} of ${count_total} files"
echo "  (${count_skipped} already normalized on previous run)"
echo "Originals backed up in:  tmp/originals/"
echo "To restore any file:     mv tmp/originals/<name>.mp3 ./"
