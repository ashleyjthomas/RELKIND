# Twizzle Town

A child developmental psychology study, hosted as a self-contained web game on GitHub Pages.

**Live game:** https://ashleyjthomas.github.io/RELKIND/
**PI:** Ashley Thomas, Harvard University (`athomas@g.harvard.edu`)
**IRB:** Harvard University Area IRB

---

## What the study tests

Children ages 4–8 reason about social relationships in a fictional world populated by three kinds of characters: **Wugs** (blue), **Flurps** (orange), and **Zazzos** (green). On each trial the child meets a target character and two side characters, then sees the target do something unusual. Each side character makes a comment — one referring to the **individual** (e.g., *"Hmm, Rowan must like to play with bugs"*), the other referring to the **group** (e.g., *"Hmm, Wugs must like to play with bugs"*). The child is then asked one of two questions:

- **Closer:** Who is the target closer to?
- **Boss:** Who is the target's boss?

We're testing whether children use individual-vs-group framing as a cue to social-relational structure (closeness vs. authority), and whether **epistemic certainty** of the comment ("Hmm…must" vs. "Yes…") modulates that inference.

### Design

| Factor | Levels |
|---|---|
| Question block | Closer / Boss (within-subjects; both blocks, order randomized) |
| Epistemic certainty | Hmm (uncertain) / Yes (confident) — between-block, randomized |
| Role assignment | A=group / A=individual — between-block, randomized |
| Character set | Version A / Version B — within-subjects, each block uses a different set |
| Left-right swap | Speakers swap sides on each trial (50/50, online) |

Each child completes **12 trials** (6 per block) plus a mid-game video break.

---

## How the game runs

### Through Children Helping Science (production)

CHS hands off to the game in a new tab with two URL parameters:

```
https://ashleyjthomas.github.io/RELKIND/?pid=<TT###_timestamp>&chsid=<response_uuid>
```

- `pid` is the assigned condition (e.g. `TT042_1747234567890`) used as `participantId` in the data
- `chsid` is the CHS response UUID, stored alongside as `chsId` for cross-referencing

The setup screen asks for the child's first name and age, then proceeds.
When the child finishes, the game posts `{type: 'GAME_COMPLETE'}` via `window.postMessage` so CHS's parent timeline can advance.

### Standalone (testing / piloting)

Visiting the bare URL `https://ashleyjthomas.github.io/RELKIND/` works too: the setup screen will use the typed first name as the `participantId` and leave `chsId` blank. Useful for QA and demos.

---

## Data flow

Each completed trial is sent two ways:

1. **Auto-uploaded to a Google Sheet** via an Apps Script webhook. The first POST writes the header row; subsequent POSTs append one row per response. See [`scripts/apps_script.gs`](scripts/apps_script.gs) for the receiver code; the webhook URL is hardcoded in `index.html` as `SHEETS_WEBHOOK`.
2. **Stored locally** in `localStorage` and downloadable as CSV from the researcher panel (see below).

### Column schema

37 columns in this order:

| Group | Columns |
|---|---|
| Identification | `participantId`, `chsId`, `firstName`, `age` |
| Counterbalancing | `versionThisBlock`, `versionClose`, `versionBoss`, `blockBoss`, `blockClose`, `blockOrder`, `blockCurrent` |
| Condition | `questionType`, `epistemic`, `blockRoleA`, `blockRoleB`, `rolesSwapped`, `effectiveRoleA`, `effectiveRoleB` |
| Stimulus | `dataExportTag`, `target`, `behavior`, `personA`, `groupA`, `personB`, `groupB`, `speechA`, `speechB` |
| Images shown | `portraitImgShown`, `actionImgShown`, `orangeImgShown`, `greenImgShown` |
| Response | `chosenName`, `chosenGroup`, `chosenRole`, `responseRecode`, `hypothesisConsistent` |
| Timing | `rt_ms`, `timestamp` |

`hypothesisConsistent` is the key analysis variable (1 = predicted direction: individual-speaker on closer trials OR group-speaker on boss trials; 0 = opposite).

---

## Researcher controls

Hidden by default. Two ways to reveal the researcher panel:

- **Touch:** 5 quick taps anywhere in the top-right 48 × 48 px of the screen (within 3 seconds)
- **Keyboard:** Shift + R

The panel exposes:

- **Next Trial →** — advance without recording a response
- **Skip Block →** — jump to the mid-game video / next block
- **Jump to Trial #...** — prompt for story 1–12 and jump directly there
- **Download CSV** — local export of everything in `G.resp`
- **Skip to End** — jump to the celebration screen

A separate **fullscreen toggle** lives discreetly in the top-left corner.

---

## Project structure

```
RELKIND/
├── README.md                          ← you are here
├── index.html                         ← the entire game (HTML + CSS + JS)
├── .gitignore
│
├── *.mp3                              ← 166 audio files (see below)
├── *.png                              ← 147 image files (see below)
├── mixkit-three-funny-...mp4          ← shared mid-game + end-game video
│
└── scripts/
    ├── apps_script.gs                 ← Google Sheets webhook receiver
    ├── generate_v10_audio.py          ← generates 12 character intros + mid/end videos
    ├── regen_setup_audio.py           ← regenerates setup.mp3
    └── regen_setup_age_audio.py       ← regenerates setup_age.mp3 (CHS-mode variant, unused in v11.2+)
```

### Image conventions

| Pattern | Use |
|---|---|
| `{char}.png` | Target character portrait (rowan, casey, taylor, …) |
| `{char}_{behavior}.png` | Action scene (e.g. `rowan_bugs.png`, `taylor_walls.png`) |
| `orange{n}.png`, `green{n}.png` | Pool of generic Flurps/Zazzos used randomly for side characters |
| `{char}_{behavior}_v{n}.png` | Alternative renders kept for reference, **not used by the game** |
| `{name}_portrait_v{n}.png` | Alternative side-character portraits, **not used by the game** |
| `CShugging.png` | Definition image shown in Closer block |
| `ARchair.png` | Definition image shown in Boss block |
| `title_card.png` | Welcome screen title image |
| `star_reward.png`, `heart_icon.png`, `crown_icon.png` | Decorative |

### Audio conventions

Per-character (each of 12 trial characters: rowan, casey, taylor, alex, jordan, riley, sam, theo, sage, blake, wren, arlo):

| Suffix | Content |
|---|---|
| `_intro` | *"Now you'll meet X. X has known Y and Z for several years…"* |
| `_likeA` / `_likeB` | *"X and Y like each other a lot."* (animated speech) |
| `_action` | *"One day you see X doing …"* |
| `_ask` | *"You asked Y and Z about it."* |
| `_hmm_group` / `_hmm_ind` | Uncertain speech ("Hmm, Wugs must like to…" / "Hmm, X must like to…") |
| `_yes_group` / `_yes_ind` | Confident speech ("Yes, Wugs like to…" / "Yes, X likes to…") |
| `_q_close` / `_q_boss` | Per-character question prompt |
| `_reread` | Combined re-narration for the Replay button |

Shared:

| File | Content |
|---|---|
| `setup.mp3` | *"What's your first name? How old are you?"* |
| `intro_village.mp3` | *(Unused as of v11.1 — intro now reuses `intro_ready`)* |
| `intro_wugs.mp3`, `intro_flurps.mp3`, `intro_zazzos.mp3` | Group introductions |
| `intro_ready.mp3` | *"Wugs, Flurps, and Zazzos all live in Twizzle Town! Are you ready to meet some of them?"* |
| `block_close.mp3`, `block_boss.mp3` | Block-level question explanations |
| `mid_video.mp3` | *"Great job! You still have some more questions — but first, watch this funny video!"* |
| `end_video.mp3` | End-screen celebration narration |
| `star_done.mp3`, `star_halfway.mp3`, `star_generic.mp3` | Star-earned celebrations |
| `welcome.mp3`, `end.mp3` | Older narration kept for reference |

All current production audio was generated with ElevenLabs voice ID `CBHdTdZwkV4jYoCyMV1B`.

---

## Updating the game

The whole game is one HTML file (`index.html`) — no build step, no dependencies, no server.

1. Edit `index.html` directly in any editor.
2. Commit and push (via GitHub Desktop is easiest).
3. GitHub Pages redeploys automatically in ~30 seconds.

For audio changes, run the relevant script in `scripts/` with your ElevenLabs API key in the environment, then commit the new MP3s. See each script's docstring for usage.

To change the Google Sheets destination: redeploy a new Apps Script Web App (see `scripts/apps_script.gs`), paste the new URL into `index.html` as `SHEETS_WEBHOOK`, and push.

---

## Version history

| Version | Notable changes |
|---|---|
| **v11.2** | First-name + age setup screen in both standalone and CHS modes |
| **v11.1** | Capture CHS `?pid` and `?chsid` separately; researcher panel shows both |
| **v11** | Auto-upload trial responses to Google Sheets via Apps Script |
| **v10.2** | Fix audio race on screen change; compact speech phase + auto-scroll-to-choices; fullscreen toggle; hidden researcher panel with skip controls |
| **v10.1** | Drop "friends" framing from intro; merge title slide |
| **v10** | Restored relationship-setup story text; tighter layout; first-name field; CHS ID auto-grab; definition images for Closer/Boss blocks; end-screen video |
| **v9** | Nunito font; emojis replaced with SVG icons |
| **earlier** | Mid-game video; ElevenLabs narration; CHS integration via postMessage |
