# Pre-Registration: Twizzle Town

**Study title:** *Friends in Twizzle Town: How children use individual- versus group-referring language to reason about closeness and authority*

**Principal Investigator:** Ashley Thomas, Harvard University (`athomas@g.harvard.edu`)
**Hosting platform:** Children Helping Science (CHS)
**Game URL:** https://ashleyjthomas.github.io/RELKIND/
**IRB:** Harvard University Area IRB (approved)
**Date of pre-registration:** _to be filled in upon submission_

---

## 1. Background

When people describe someone's behavior, they can frame it as a property of the **individual** (e.g., *"Rowan likes to play with bugs"*) or as a property of the **group** the individual belongs to (e.g., *"Wugs like to play with bugs"*). Adults are sensitive to these framing differences and use them to infer the speaker's relationship to the target — group-level generalizations imply the speaker stands apart from the target (e.g., as a leader or outside-observer), whereas individual-level descriptions imply a more particular, perhaps closer, relationship (Thomas et al., in prep; cf. Rhodes & Mandalaywala, 2017).

We ask whether children ages 5–8 use this same cue when inferring the structure of social relationships. Specifically, we test whether children link group-referring speech to **authority** (the speaker is the target's "boss") and individual-referring speech to **closeness** (the speaker is the target's friend / closer to the target). We also manipulate the **epistemic certainty** of the comment ("Hmm…must" vs. "Yes…") to ask whether confidence interacts with the individual/group cue.

### Pilot data

We treat the data collected to date (N ≈ 30 participants, ages 4–7) as **pilot data**. The pilot informed three design decisions:

1. **Excluding 4-year-olds from the registered sample.** Performance and engagement at age 4 in the pilot suggested the task is too verbally demanding for many 4-year-olds (qualitative observations from session videos plus near-chance overall responding at this age).
2. **Adding 8-year-olds.** Older children appeared more sensitive to the manipulation; we extend the upper bound to determine whether the effect grows or plateaus by age 8.
3. **Planning age-group comparisons.** Patterns in the pilot suggested possible age effects; we register an explicit age-group test alongside the omnibus analysis.

## 2. Hypotheses

**H1 — Main effect (Boss block).** When the question is *"Who is the target's boss?"*, children will be more likely to choose the **group-referring speaker** than the individual-referring speaker (proportion > .5, hypothesis-consistent).

**H2 — Main effect (Closer block).** When the question is *"Who is the target closer to?"*, children will be more likely to choose the **individual-referring speaker** than the group-referring speaker (proportion > .5, hypothesis-consistent).

**H3 — Age effect.** Hypothesis-consistent responding will be stronger in older children (ages 7–8) than younger children (ages 5–6).

**H4 — Epistemic modulation (exploratory).** We will test whether the speaker's expressed certainty (*"Hmm…must"* vs. *"Yes…"*) moderates H1 and H2. We have no strong directional prediction.

## 3. Design

A 2 (Question type: Closer / Boss) × 2 (Epistemic certainty: Hmm / Yes) within-subjects design over 12 trials. Each child completes one block of each question type (6 trials per block). Within each block, the epistemic frame is held constant and the role assignment (which speaker generalizes vs. individuates) is randomly assigned. Block order, epistemic frame, role assignment, character set (A / B), and left-right position of speakers are counterbalanced across participants. See `README.md` for the full counterbalancing scheme.

## 4. Sampling plan

### Target sample

- **Ages 5–8 years**, recruited through Children Helping Science.
- **Target N:** 80 children (20 per year of age), with the goal of at least 64 retained after exclusions (16 per age).
- **Stopping rule:** Recruit until at least 16 retained per year of age (4, 5, 6, 7, 8 ≥ 16 each, after applying exclusion criteria below). If recruitment reaches 120 total sessions and the target is not met for one age, we will stop and report sample sizes as obtained.

### Inclusion criteria

- Caregiver-reported age 5.00 – 8.99 years on date of session
- Caregiver consented to participate and to data sharing
- Child completed at least one experimental trial

### Exclusion criteria (applied in order)

1. Records with `participantId` or `firstName` equal to `TEST`, `TESTING`, `pilot`, or matching a researcher account
2. Duplicate sessions for the same participant — keep only the first complete or partial session
3. Children under 5.0 years
4. Sessions in which the child was clearly distracted, prompted by the caregiver, or otherwise non-compliant per video review (coded independently by two RAs blind to condition; disagreements resolved by discussion). Whole sessions excluded; individual-trial exclusions are not used.

We will report the number of participants lost at each exclusion step.

## 5. Variables

### Outcome
- `hypothesisConsistent` (0/1, per trial): 1 if the chosen speaker is in the hypothesis-predicted role (group-speaker on Boss trials; individual-speaker on Closer trials), 0 otherwise.

### Within-subject manipulations
- `questionType`: Closer (the target is asked about who they are closer to) vs. Boss (who is in charge)
- `epistemic`: Hmm (tentative) vs. Yes (confident)

### Between-subject variables
- `ageGroup`: **Younger (5–6 years)** vs. **Older (7–8 years)** — see §6.2 for rationale
- `age`: years (continuous, for sensitivity analyses)

### Covariates / nuisance variables (modeled but not interpreted)
- `rolesSwapped` (TRUE/FALSE, left-right position)
- `blockOrder` (which block came first)
- `characterSet` (A / B)
- `trialNumber` (1–12)

## 6. Analysis plan

All analyses will be conducted in R using **brms** (Bürkner, 2017) for Bayesian hierarchical models and **BayesFactor** for one-sample comparisons. Code is committed to the project repository.

### 6.1 Primary confirmatory analysis

We will fit a Bayesian hierarchical logistic regression predicting `hypothesisConsistent` from question type, epistemic frame, age group, and their interactions, with random intercepts (and where feasible, random slopes) by participant:

```r
brm(
  hypothesisConsistent ~ questionType * epistemic * ageGroup
                       + (1 + questionType + epistemic | participantId),
  family = bernoulli(),
  prior  = c(
    prior(normal(0, 1.5), class = "Intercept"),
    prior(normal(0, 1),   class = "b"),
    prior(exponential(2), class = "sd")
  ),
  data   = dat,
  iter   = 4000, warmup = 1000, chains = 4, cores = 4,
  control = list(adapt_delta = 0.95)
)
```

**Priors.** Weakly informative on the log-odds scale: `Normal(0, 1.5)` on the intercept (covers ~5%–95% prior probability on any cell proportion); `Normal(0, 1)` on effect-coded predictors and interactions (mean prior odds-ratio of 1.0, with 95% CrI roughly 0.14–7.4); `Exponential(2)` on random-effect SDs. These priors are conservative — they down-weight extreme effects but are wide enough not to drive inference.

**Sum coding** will be used for all categorical predictors so that the intercept is interpretable as the grand-mean log-odds and coefficients represent half the difference between levels.

**Decision rules.** For each pre-registered effect we will report:
- the **95% posterior credible interval** for the coefficient on the log-odds scale and the back-transformed probability scale,
- the **posterior probability of the predicted direction** (e.g., *P*(β > 0 | data)),
- the **Bayes factor** for the effect against a null model with that term removed, using the Savage–Dickey ratio.

We will treat an effect as supported if the 95% CrI excludes zero **and** the directional posterior probability exceeds 0.95. A Bayes factor of **BF₁₀ ≥ 3** (moderate evidence) or **≥ 10** (strong) will be reported as such; **BF₁₀ ≤ 1/3** will be interpreted as evidence for the null.

### 6.2 Age groupings

Given the pilot pattern and the developmental psychology literature on a "5-to-7 shift" in social-categorical reasoning (Sameroff & Haith, 1996), we will analyze children in two age groups:

- **Younger:** 5.0 – 6.99 years
- **Older:** 7.0 – 8.99 years

We chose to **group 6-year-olds with the younger sample** rather than with the older sample for three reasons: (1) it produces approximately equal age spans in each group (2 years each), (2) it places the conceptual boundary at the canonical 5-to-7 shift, and (3) 6-year-olds in the pilot data patterned more closely with 5-year-olds than with 7-year-olds on the hypothesis-consistent outcome. We will additionally fit a continuous-age model as a sensitivity check (§6.5).

### 6.3 Cell-level chance tests

For each (`questionType` × `epistemic`) cell, we will conduct a Bayesian one-sample test of per-participant proportions against chance (0.5):

```r
BayesFactor::ttestBF(x = pp$p_hypothesis, mu = 0.5, nullInterval = c(0.5, 1))
```

The directional `nullInterval = c(0.5, 1)` matches our directional predictions for H1 and H2. We will report the BF₊₀ (above-chance vs. null) and the 95% posterior credible interval on the cell proportion.

### 6.4 Age-stratified analyses

We will refit the §6.1 model separately within each age group, dropping the `ageGroup` term:

```r
brm(hypothesisConsistent ~ questionType * epistemic
                         + (1 + questionType + epistemic | participantId),
    family = bernoulli(), ..., data = subset(dat, ageGroup == "Older"))
```

We will also report cell means and BFs (§6.3) stratified by age group.

### 6.5 Sensitivity analyses (registered)

1. **Continuous age.** Refit §6.1 with age centered and entered as a continuous predictor (replacing `ageGroup`).
2. **Prior sensitivity.** Refit §6.1 with (a) tighter priors (`Normal(0, 0.5)` on coefficients) and (b) wider priors (`Normal(0, 2.5)`).
3. **Trial-count threshold.** Refit §6.1 restricting to participants who completed all 12 trials.
4. **6-year-olds with the older group.** Refit §6.1 grouping 6-year-olds with 7–8 instead of 5–6, to check whether the age-grouping decision drives any inferential conclusions.

All sensitivity analyses will be reported regardless of outcome.

### 6.6 Exploratory analyses (not confirmatory)

- Role of expressed certainty (`epistemic`) as a moderator of H1 and H2 separately within each age group.
- Response-time analyses (log-RT as a continuous outcome) to check whether age and condition affect deliberation.
- Item-level random effects (random intercepts by `target` character).
- Effects of `rolesSwapped`, `blockOrder`, and `characterSet` as fixed effects (not predicted to matter; reported for transparency).

## 7. Outcomes-neutral reporting

We commit to reporting:
- All exclusions with counts at each step
- All pre-registered analyses regardless of whether they support hypotheses
- All sensitivity analyses (§6.5) regardless of whether they overturn primary conclusions
- Any data-driven deviations from this plan, clearly labeled as exploratory

## 8. Materials and data availability

- **Stimuli and game code:** https://github.com/ashleyjthomas/RELKIND (MIT-licensed)
- **Pre-registered analysis code:** `scripts/analyze_twizzle.R` (frequentist version; Bayesian version to be added prior to data analysis as `scripts/analyze_twizzle_bayes.R`)
- **Data:** raw trial-level data will be deposited on OSF upon project completion, with identifying fields (`firstName`, `chsId`) stripped.

## 9. References

Bürkner, P.-C. (2017). brms: An R package for Bayesian multilevel models using Stan. *Journal of Statistical Software, 80*(1), 1–28.

Rhodes, M., & Mandalaywala, T. M. (2017). The development and developmental consequences of social essentialism. *WIREs Cognitive Science, 8*(4), e1437.

Sameroff, A. J., & Haith, M. M. (Eds.). (1996). *The five to seven year shift: The age of reason and responsibility.* University of Chicago Press.
