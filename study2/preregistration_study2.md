---
editor_options:
  markdown:
    wrap: 72
output:
  html_document:
    df_print: paged
---

# Pre-Registration (Study 2): Children's joint inferences about relationships from the way people explain behavior.

**Author:** Ashley Thomas, Harvard University (`athomas@g.harvard.edu`)
**Hosting platform:** Children Helping Science (CHS)

**Game URL:** <https://ashleyjthomas.github.io/RELKIND/> (serves the
Study 2 game at `study2/`; the Study 1 game is archived at
`study1.html`) **IRB:** Harvard University Area IRB (approved)

**Date of pre-registration:** [DATE]

------------------------------------------------------------------------

## 1. Background

When people explain someone's behavior, they can frame it as a property
of the **individual** (e.g., *"Rowan likes to play with bugs"*) or as a
property of the **group** the individual belongs to (e.g., *"Wugs like
to play with bugs"*). Adults use these framing differences to infer the
speaker's relationship to the target: they infer social intimacy from
individual-level explanations as opposed to group-level explanations
(Thomas et al., in prep).

In **Study 1** (pre-registered 06/19/2026; N = 127 children ages 5--8
after exclusions) children answered, on separate blocks of trials,
*"Who is [target]'s best friend?"* or *"Who is [target]'s boss?"*,
choosing between an individual-level explainer and a group-level
explainer. Children --- especially 7--8-year-olds --- chose the
individual-level explainer as the **best friend** above chance.
However, contrary to our prediction, children also tended to choose the
individual-level explainer as the **boss**: the overall rate of
choosing the individuating speaker was \~63% in *both* blocks, and only
older children showed relative differentiation between the two
questions. Study 1 therefore cannot distinguish (a) a mapping from
individuation to *closeness specifically* from (b) a general preference
for, or attention-based inference about, the individuating speaker that
attaches to *any* salient relationship.

**Study 2** removes this ambiguity by forcing a trade-off. On every
trial, children meet a target and two speakers (one explains the
target's behavior at the individual level, one at the group level) and
are told that one of the two speakers is the target's **best friend**
and the other is the target's **boss**. Children choose between the two
complete assignments (X = best friend & Y = boss, or the reverse). A
general preference for the individuating speaker can no longer produce
the predicted pattern: assigning the individual-level explainer to the
best-friend role *necessarily* assigns the group-level explainer to the
boss role. As in Study 1, we also manipulate the speaker's expressed
epistemic state ("Hmm...must" vs. "Yes...").

### Pilot data

Data collected with the Study 2 game before [DATE/TIME ET] are treated
as **pilot data** and excluded from confirmatory analyses. Piloting was
used to shorten the session (4 test trials), remove one item with a
stimulus error (the "Alex" item), fix the option-display so the two
speakers appear (and are read aloud) in the same left-right positions
on both response options, and deliver the best-friend/boss framing
before children hear the speakers' explanations.

## 2. Hypotheses

**H1 --- Joint assignment (primary).** When assigning the two roles,
children will assign the **individual-level explainer to the
best-friend role** (and therefore the group-level explainer to the boss
role) more often than chance (proportion \> .5, hypothesis-consistent).

**H2 --- Age effect.** Hypothesis-consistent responding will be
stronger in older children (7--8 years) than younger children (5--6
years). Based on Study 1 (questionType x age interaction; continuous
exact-age model BF10 ≈ 5.7), we predict the effect will increase with
age; younger children may not differ from chance.

**H3 --- Epistemic modulation (exploratory).** We will test whether the
speaker's expressed certainty ("Hmm...must" vs. "Yes...") moderates H1.
In Study 1 the epistemic manipulation had no effect (moderate evidence
for the null); we retain it as an exploratory manipulation and make no
directional prediction.

## 3. Design

A 2-level within-subjects design over **4 test trials**: two blocks of
2 trials, one block per **epistemic frame** (Hmm / Yes), with the
epistemic frame held constant within a block. There is no
question-type manipulation: every trial asks the child to assign
*both* the best-friend and the boss roles simultaneously by choosing
between two complete assignments.

On each trial: (1) the child meets the target and the two speakers and
hears that one speaker is the target's best friend and one is the
target's boss ("You'll have to figure out which is which!"); (2) the
child sees the target's unusual behavior; (3) the framing is repeated
as a reminder, then the two speakers explain the behavior (one
individual-level, one group-level; which speaker individuates is
randomized per trial); (4) the child chooses between two option cards
showing the two possible role assignments. The two speakers appear in
fixed left-right positions on both option cards (only the role labels
swap), and the option audio names the speakers in the same left-right
order as displayed. Which complete assignment appears on the
left/right card is fixed (left card = left speaker as best friend);
the role-to-speaker mapping is carried entirely by the per-trial
randomization of which speaker individuates.

Block order (Hmm-first vs. Yes-first) is randomized across
participants. Four target characters per child are drawn without
replacement from a pool of 11, randomized per participant. See
`study2/` in the project repository for the full game and
counterbalancing implementation.

## 4. Sampling plan

### Target sample

**Ages 5 to 8 years**, recruited through Children Helping Science.

**Target N: 100 children** (25 per year of age), with the goal of at
least **80 retained after exclusions** (20 per age).

**Stopping rule:** Recruit until at least 20 retained per year of age
(5, 6, 7, 8 ≥ 20 each, after applying exclusion criteria below). If
recruitment reaches 120 total sessions and the target is not met for
one age, we will stop and report sample sizes as obtained.

**Stopping rule:** If our data are inconclusive we may test more
children. Since we are using Bayesian statistics we can accumulate
evidence for the null.

### Inclusion criteria

-   Caregiver-reported age 5.00--8.99 years on date of session (we will
    additionally compute exact age in days from the caregiver-reported
    birthdate in the CHS exit survey and use it for continuous-age
    analyses; where the two conflict implausibly we use the more
    plausible value and report all such cases)
-   Caregiver consented to participate and to data sharing
-   Child completed at least one experimental trial

We will look at 4-year-olds as an exploratory investigation.

### Exclusion criteria

1.  Duplicate sessions for the same participant --- keep only the first
    complete or partial session
2.  Sessions in which the child was clearly distracted, prompted by the
    caregiver, or otherwise non-compliant per video review. Whole
    sessions excluded; individual-trial exclusions are not used.

We will report the number of participants lost at each exclusion step.

## 5. Variables

### Outcome

`individualAssignedTo` ∈ {best_friend, boss}: which role the child
gave the individual-level explainer. `hypothesisConsistent` = 1 when
the individual-level explainer is assigned to the **best-friend** role
(equivalently, the group-level explainer to the boss role), 0
otherwise.

### Within-subject manipulation

-   **Epistemic:** Hmm (tentative: "Hmm, [X] must like to...") vs. Yes
    (confident: "Yes, [X] likes to..."), blocked (2 trials each)

### Between-subject variables

-   **ageGroup:** Younger (5--6 years) vs. Older (7--8 years)
-   **age:** exact age in years (continuous, from CHS birthdate;
    caregiver-reported age + 0.5 where birthdate is unavailable), for
    the continuous-age analyses

## 6. Analysis plan

All analyses will be conducted in R using **brms** (Bürkner, 2017) for
Bayesian hierarchical models and **BayesFactor** for one-sample
comparisons. Code is committed to the project repository.

### 6.1 Primary confirmatory analysis

We will fit a Bayesian hierarchical logistic regression predicting
`hypothesisConsistent` from epistemic frame, age group, and their
interaction, with random intercepts by participant. (With 4 trials per
child we pre-register random intercepts only; we will not fit random
slopes.)

``` r
brm(hypothesisConsistent ~ epistemic * ageGroup + (1 | participantId),
    family = bernoulli(),
    prior  = c(prior(normal(0, 1.5), class = "Intercept"),
               prior(normal(0, 1),   class = "b"),
               prior(exponential(2), class = "sd")),
    data   = dat,
    iter   = 4000, warmup = 1000, chains = 4, cores = 4,
    control = list(adapt_delta = 0.95))
```

**H1 is tested by the intercept** (grand-mean log-odds \> 0 under sum
coding), in addition to the cell-level chance tests in §6.3. **H2 is
tested by the ageGroup coefficient** and by the continuous-age model in
§6.5.

**Priors.** Weakly informative on the log-odds scale: Normal(0, 1.5)
on the intercept; Normal(0, 1) on effect-coded predictors and
interactions; Exponential(2) on random-effect SDs. Sum coding will be
used for all categorical predictors so that the intercept is
interpretable as the grand-mean log-odds.

**Decision rules.** For each effect we will report: the 95% posterior
credible interval on the log-odds and back-transformed probability
scales; the posterior probability of the predicted direction (e.g.,
P(β \> 0 | data)); and the Bayes factor for the effect against a null
model with that term removed. We will treat an effect as supported if
the 95% CrI excludes zero and the directional posterior probability
exceeds 0.95. BF₁₀ ≥ 3 (moderate) or ≥ 10 (strong) will be reported as
such; BF₁₀ ≤ 1/3 will be interpreted as evidence for the null.

### 6.2 Age groupings

As in Study 1: **Younger** = 5.0--6.99 years, **Older** = 7.0--8.99
years (equal 2-year spans; Study 1 6-year-olds patterned with
5-year-olds). We will additionally fit a continuous-age model as a
sensitivity check (§6.5).

### 6.3 Cell-level chance tests

For each epistemic cell (and collapsed across epistemic frames), we
will conduct a Bayesian one-sample test of per-participant proportions
against chance (0.5):

``` r
BayesFactor::ttestBF(x = pp$p_hypothesis, mu = 0.5,
                     nullInterval = c(0, Inf))
```

**Note (deviation from Study 1 wording):** Study 1 pre-registered
`nullInterval = c(0.5, 1)`; that interval is on the standardized
effect-size (δ) scale rather than the proportion scale, so it
restricted the alternative to medium-to-large effects rather than
expressing directionality. The intended directional test is
`nullInterval = c(0, Inf)`, which we pre-register here. We will report
the directional BF₊₀ and the 95% posterior credible interval on the
cell proportion.

### 6.4 Age-stratified analyses

We will refit the §6.1 model separately within each age group,
dropping the ageGroup term:

``` r
brm(hypothesisConsistent ~ epistemic + (1 | participantId),
    family = bernoulli(), ...,
    data = subset(dat, ageGroup == "Older"))
```

We will also report cell means and BFs (§6.3) stratified by age group.

### 6.5 Sensitivity analyses

1.  **Continuous age.** Refit §6.1 with exact age (centered, from CHS
    birthdate) as a continuous predictor replacing ageGroup.
2.  **Prior sensitivity.** Refit §6.1 with (a) tighter priors
    (Normal(0, 0.5) on coefficients) and (b) wider priors
    (Normal(0, 2.5)).
3.  **Trial-count threshold.** Refit §6.1 restricting to participants
    who completed all 4 trials.
4.  **6-year-olds with the older group.** Refit §6.1 grouping
    6-year-olds with 7--8 instead of 5--6.

### 6.6 Exploratory analyses (not confirmatory)

-   Response-time analyses (log-RT as a continuous outcome).
-   Item-level random effects (random intercepts by target character).
-   Effects of counterbalancing nuisance variables (`rolesSwapped`,
    block order) as fixed effects (not predicted to matter; reported
    for transparency).
-   Trial-order effects within session (only 4 trials; reported for
    transparency).
-   Open-ended "why?" responses: after the last trial of each block,
    the child is asked "Why do you think that?" and the caregiver types
    the child's answer. These will be coded qualitatively (coding
    scheme developed after data inspection) and reported as exploratory.
-   4-year-olds.
-   Comparison with Study 1: we will descriptively compare the Study 2
    joint-assignment rate with the Study 1 best-friend-block rate, and
    may fit a combined model with study as a factor (exploratory).

## 7. Materials and data availability

**Stimuli and game code:**
<https://github.com/ashleyjthomas/RELKIND> (Study 2 game in `study2/`)

**Pre-registered analysis code:** `scripts/analyze_study2_bayes.R`
(committed before confirmatory data collection begins)

**Data:** raw trial-level data will be deposited on OSF upon project
completion, with identifying fields (`firstName`, `chsId`, birthdates)
stripped.

## 8. References

Bürkner, P.-C. (2017). brms: An R package for Bayesian multilevel
models using Stan. *Journal of Statistical Software, 80*(1), 1--28.
