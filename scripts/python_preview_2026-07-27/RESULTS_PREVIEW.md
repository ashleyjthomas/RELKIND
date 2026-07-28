# RELKIND — Preview of pre-registered analyses (2026-07-27)

**What this is.** A Python (numpyro) replication of `analyze_twizzle_bayes.R` — same model
formulas, sum coding, and priors (Normal(0,1.5) intercept, Normal(0,1) betas, Exponential(2)
SDs; random intercepts + questionType/epistemic slopes by participant) — run on the cleaned
post-registration data. R/brms could not run in the sandbox; treat this as a preview and run
the R script for the confirmatory record. Results should match up to MCMC error.

**Data.** `twizzle_data_postreg_clean.csv`: sessions on/after 6/19/26 2pm ET, TEST rows
removed, duplicate sessions (same firstName+age) dropped keeping the first (JONAH 8,
JULIANA 7, CHASE 5, DHRUVITA 6; plus ALICE 4). Analysis sample ages 5-8: **127 children,
1,511 trials** (5: 29, 6: 28, 7: 32, 8: 38 — stopping rule of >=20/age met, pending video
exclusions). To run the R script on these data, replace `scripts/twizzle_data.csv` with
`twizzle_data_postreg_clean.csv`.

## Stopping decision

Retained N exceeds 20 per age year with margin (smallest cell: age 6, n=28). Recruitment can
stop, contingent on video review not removing >8 sessions in any single age year.

## Results by hypothesis

**H1 — best friend block: supported.** Children chose the individual-based explainer as the
best friend above chance (hmm: M=.63, yes: M=.65; pre-registered directional BFs ~ 580 and
440). Driven by older children (7-8: BFs ~ 3,270 and 145; 5-6: BFs ~ 0.04 and 1.9 — younger
children at/near chance in the hmm frame).

**H1 — boss block: reversed.** Children were predicted to choose the group-referring speaker
as the boss (>.5). Instead they chose the group speaker *below* chance (hmm: M=.39, yes:
M=.36; two-sided BF10 = 13 and 121 for a difference from chance in the *wrong* direction;
directional BFs ~ 0). Children picked the **individual-based explainer as the boss too**.

**Key interpretive caveat.** The rate of choosing the individual-explainer was ~63% in *both*
blocks (close .64, boss .63 overall). The large `questionType` coefficient in the primary
model (beta = 0.69, 95% CrI [0.46, 0.92], pd > .999) largely reflects the outcome coding flip
between blocks, not block-by-block differentiation. Only older children differentiated at all
(individual-choice: close .70 vs boss .64); younger children trended the opposite way
(.56 vs .60). See `figures_bayes_py/03_individual_choice_rate.png`. A plausible reading:
children map individual-level explanations onto *any* salient relationship, or simply prefer
the individuating speaker; the boss reversal is the theoretically interesting result to dig into.

**H3 — age: directionally supported, evidence weak.** questionType x ageGroup beta = -0.26,
95% CrI [-0.47, -0.03], pd = .987 (Younger coded +1, so the effect is larger in older
children), but Savage-Dickey BF10 ~ 1.3 (anecdotal). Age-stratified models: questionType
effect beta = 0.38 [0.15, 0.65] in younger vs 1.01 [0.65, 1.42] in older.

**H4 — epistemic (exploratory): no effect; evidence for the null.** Epistemic main effect
beta ~ 0.00 [-0.18, 0.18], BF10 ~ 0.09 (moderate evidence for null); all epistemic
interactions similarly null. The pilot's "yes-only" pattern in older children did **not**
replicate (older, close block: hmm .72 vs yes .69).

**Sensitivity analyses.** Conclusions unchanged under continuous age, tighter/wider priors,
complete-cases-only, and 6-year-olds grouped with older (all in `tables_bayes_py/`).
All fits converged (Rhat <= 1.003).

## Two things to fix before running confirmatory R analyses

1. **`ttestBF` nullInterval bug.** The pre-registration and script use
   `nullInterval = c(0.5, 1)`. That interval is on the *standardized effect size (delta)*
   scale, not the proportion scale — it restricts the alternative to delta in [0.5, 1]
   (medium-to-large effects only), which is not "above chance." The intended directional test
   is `nullInterval = c(0, Inf)`. Both versions are reported in the chance-test CSVs here
   (qualitative conclusions are unaffected). Worth documenting as a deviation.
2. **The R script does not filter pilot data or duplicate sessions.** It only de-duplicates
   trials within a participant. Use `twizzle_data_postreg_clean.csv` as input (see above),
   and apply video-review exclusions to it before the final run.

## Files

- `tables_bayes_py/` — posterior summaries (median, 95% CrI, pd, Savage-Dickey BF10, Rhat)
  for the primary, age-stratified, and sensitivity models; cell-level chance tests overall
  and by age; per-participant cell means.
- `figures_bayes_py/` — cell means (overall, by age group), individual-choice-rate figure.
- `common.py`, `run_fit.py`, `cell_tests.py`, `figures.py` — replication code.

*Not run here (needs R/brms): exploratory RT model, item random effects, nuisance checks.*

## Update (same day): exact ages from CHS frame data

Birthdates from the exit survey were linked to game sessions via `assigned_condition`
(= game participantId): **154 of 161** post-registration sessions matched
(`participant_exact_ages.csv`; unmatched kept reported age + 0.5). Three flags:

- TT069 (reported 8): DOB gives 47.5 yrs — caregiver entered own DOB; reported age kept.
- TT048: reported 7, DOB-derived **8.18** (still Older group).
- TT057: reported 5, DOB-derived **6.58** (still Younger group).

Per-year counts using exact ages: 5: 28, 6: 29, 7: 31, 8: 39 — stopping rule still met.
No one falls outside the 5.00-8.99 window by exact age.

**Continuous exact-age model** (`m_age_exact_continuous_posterior.csv`): the
questionType x age interaction strengthens relative to the categorical model —
beta = 0.29, 95% CrI [0.10, 0.48], pd = .999, Savage-Dickey BF10 ~ 5.7 (moderate evidence),
plus an age main effect (beta = 0.14 [0.02, 0.27], pd = .986). H3 is better supported with
exact ages.

See `figures_bayes_py/04_age_continuous.png`: panel A, hypothesis-consistent responding by
age and question; panel B, the clearer story — choice of the individuating speaker rises
steeply with age for the *best friend* question (crossing chance ~5.5 yrs) while staying
flat around .6 for the *boss* question. Data files: `twizzle_data_with_exact_age.csv`
(trial-level, `age_best` column), `chs_link.csv` (uuid -> participantId -> DOB mapping —
contains DOBs, do not deposit publicly).
