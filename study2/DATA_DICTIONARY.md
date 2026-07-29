# RELKIND Study 2 — Data Dictionary

One row per test trial (4 rows per complete session). The sheet is shared
with Study 1, so it also contains Study-1 columns that are **blank** in
Study 2 rows (listed at the bottom). Filter on `study == "study2"` and
`timestamp` after the registration date for confirmatory data.

## Reading a row in 10 seconds

The child chooses between two complete role assignments. `chosenName` is
the person the child made the **best friend**; the other speaker is the
boss. `individualAssignedTo` tells you where the individual-level
explainer ended up, and `hypothesisConsistent = 1` means the child gave
the individual-explainer the best-friend role (the pre-registered H1
response).

## Session / participant

| Column | Values | Meaning |
|---|---|---|
| `study` | `study2` | Row source; Study-1 rows lack this or differ. |
| `participantId` | e.g. `TT042_17829...` | CHS-assigned ID passed via URL (`?pid=`); falls back to typed first name when run outside CHS. Non-`TT` values are test sessions. |
| `chsId` | string or blank | CHS response/session ID if passed via URL (`?chsid=`). |
| `firstName` | string | Name typed at setup. Identifying — strip before deposit. |
| `age` | 4–8 | Age button pressed at setup (caregiver/child report). Exact age comes from linking the CHS exit-survey birthdate. |
| `timestamp` | ISO 8601 UTC | When the choice was recorded. |

## Trial structure

| Column | Values | Meaning |
|---|---|---|
| `blockOrder` | `yes_hmm` / `hmm_yes` | Order of the two epistemic blocks for this child. |
| `blockIndex` | 0, 1 | Which block this trial is in (0 = first). |
| `trialInBlock` | 0, 1 | Trial within block (2 per block). |
| `epistemic` | `hmm` / `yes` | Epistemic frame of this block: tentative ("Hmm, ... must like to") vs. confident ("Yes, ... likes to"). |
| `dataExportTag` | e.g. `casey_yes` | targetKey + epistemic; unique per participant × trial. |

## Stimuli shown

| Column | Values | Meaning |
|---|---|---|
| `target` | e.g. `Casey` | Target character (a Wug) whose behavior is explained. Drawn without replacement from 11 characters, 4 per child. |
| `behavior` | e.g. `night` | The unusual behavior for this target. |
| `personA` / `groupA` | name / `flurp` | LEFT/top speaker and their group. |
| `personB` / `groupB` | name / `zazzo` | RIGHT/bottom speaker and their group. |
| `speechA` / `speechB` | sentence | Exactly what each speaker said. The individual-level speaker names the target; the group-level speaker says "Wugs...". |
| `portraitImgShown`, `actionImgShown` | filename | Target portrait and behavior image. |
| `orangeImgShown`, `greenImgShown` | filename | Portrait images used for personA (orange) / personB (green). |

## Randomization (per trial)

| Column | Values | Meaning |
|---|---|---|
| `rolesSwapped` | TRUE/FALSE | Per-trial coin flip for which speaker individuates. FALSE: personA = individual-level explainer. TRUE: personA = group-level. |
| `blockRoleA` / `blockRoleB` | `individual` / `group` | Same information as effectiveRoleA/B (kept for parity with Study 1 export). |
| `effectiveRoleA` / `effectiveRoleB` | `individual` / `group` | Explanation level actually used by personA / personB on this trial. |
| `optionOrder` | `A_left` | Which option card was on the left. Fixed to `A_left` in the final design (left card = personA as best friend); the randomization lives in `rolesSwapped`. |

## Response (the part you asked about)

| Column | Values | Meaning |
|---|---|---|
| `optionChosenIndex` | `A` / `B` | Card clicked. `A` (left) = "personA is best friend & personB is boss"; `B` (right) = the reverse. |
| `chosenName` | name | Speaker the child put in the **best-friend** slot. The other speaker is the boss. |
| `chosenGroup` | `flurp` / `zazzo` | Group of that best-friend speaker. |
| `chosenRole` | `individual` / `group` | Whether the best-friend speaker was the individual- or group-level explainer. |
| `individualAssignedTo` | `best_friend` / `boss` | **DV.** Role the child gave the individual-level explainer. |
| `hypothesisConsistent` | 1 / 0 | 1 = individual-explainer assigned to best friend (H1-consistent). Equals `chosenRole == "individual"`. |
| `rt_ms` | integer | Time from choice-screen onset to card click, in ms. |
| `whyAnswer` | free text or blank | Caregiver-typed answer to "Why do you think that?". Asked once per block, on its **last** trial (`trialInBlock == 1`); blank on other trials or if skipped. |
| `why_rt_ms` | integer or blank | Time the why screen was open before Continue, in ms. |

## Study-1 legacy columns (blank in Study 2 rows)

`versionThisBlock`, `versionClose`, `versionBoss`, `blockBoss`,
`blockClose`, `blockCurrent`, `questionType`, `askedRole`,
`responseRecode`. These exist only because both studies share one sheet
header; ignore them for Study 2.

## Quick sanity identities

- `hypothesisConsistent == (chosenRole == "individual")`
- `individualAssignedTo == "best_friend"` iff `hypothesisConsistent == 1`
- If `rolesSwapped == FALSE`: choosing card `A` ⇒ `hypothesisConsistent = 1`; if TRUE: card `B` ⇒ 1.
- Complete session = 4 rows, `blockIndex`/`trialInBlock` = (0,0), (0,1), (1,0), (1,1), with exactly two distinct `epistemic` values and 4 distinct `target`s.
