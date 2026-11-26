#!/usr/bin/env python3
"""Equalize loudness of all study2 mp3 clips to -16 LUFS using a plain
linear gain (ffmpeg volume filter). Works reliably on short TTS clips,
unlike loudnorm. Peak-safe: gain is capped so true peak stays <= -1 dBFS.

Idempotent via tmp/equalize_done.txt; originals in tmp/pre_equalize/.
Re-run until it prints Complete.
"""
import os, re, subprocess, sys, time

TARGET_I = -16.0
D = os.path.dirname(os.path.abspath(__file__))
os.chdir(D)
os.makedirs('tmp/pre_equalize', exist_ok=True)
DONE_F = 'tmp/equalize_done.txt'
done = set(open(DONE_F).read().split()) if os.path.exists(DONE_F) else set()

def measure(f):
    r = subprocess.run(['ffmpeg', '-hide_banner', '-i', f,
                        '-af', 'ebur128=peak=true', '-f', 'null', '-'],
                       capture_output=True, text=True)
    tail = r.stderr[r.stderr.rfind('Integrated loudness'):]
    i = re.search(r'I:\s*(-?[\d.]+)\s*LUFS', tail)
    p = re.search(r'Peak:\s*(-?[\d.]+)\s*dBFS', r.stderr[r.stderr.rfind('True peak'):])
    return (float(i.group(1)) if i else None, float(p.group(1)) if p else None)

files = sorted(f for f in os.listdir('.') if f.endswith('.mp3'))
t0, n = time.time(), 0
for f in files:
    if f in done:
        continue
    if time.time() - t0 > 35:
        print(f'TIME BUDGET — rerun to continue. {len(done)}/{len(files)} done')
        sys.exit(3)
    I, peak = measure(f)
    if I is None or I < -70:               # silent/unmeasurable: leave as-is
        print(f'{f:<34} unmeasurable (I={I}) — left unchanged')
        done.add(f); open(DONE_F, 'w').write('\n'.join(done)); continue
    gain = TARGET_I - I
    if peak is not None:                   # cap so peak stays <= -1 dBFS
        gain = min(gain, -1.0 - peak)
    if abs(gain) < 0.5:
        print(f'{f:<34} I={I:6.1f}  on target')
        done.add(f); open(DONE_F, 'w').write('\n'.join(done)); continue
    tmp = 'tmp/_eq.mp3'
    r = subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', f,
                        '-af', f'volume={gain:.2f}dB', '-ar', '44100', '-b:a', '128k', tmp],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f'{f:<34} FFMPEG FAIL {r.stderr[:80]}'); continue
    if not os.path.exists(os.path.join('tmp/pre_equalize', f)):
        os.replace(f, os.path.join('tmp/pre_equalize', f))
    os.replace(tmp, f)
    done.add(f); open(DONE_F, 'w').write('\n'.join(done))
    n += 1
    print(f'{f:<34} I={I:6.1f}  gain {gain:+.1f} dB')

print(f'\nComplete: {len(done)}/{len(files)} ({n} adjusted this run)')
