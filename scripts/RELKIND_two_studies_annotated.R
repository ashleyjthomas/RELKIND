# =============================================================================
#   RELKIND: TWO STUDIES, ONE ANNOTATED SCRIPT
#   Study 1 ("Twizzle Town"): separate best-friend and boss questions
#   Study 2 ("Friends in Twizzle Town"): forced-choice (best friend vs. boss)
#
#   WHO THIS IS FOR
#   A reader who is new to R, RStudio, and Bayesian statistics. Every step is
#   commented: what the code does, and WHY we do it.
#
#   HOW TO RUN IT
#   1. Open this file in RStudio (File > Open File...).
#   2. Make sure these two data files sit in the SAME folder as this script:
#        - twizzle_data.csv   (Study 1 trials, one row per trial)
#        - study2_data.csv    (Study 2 trials, one row per trial)
#   3. Click "Source" (top right of the editor pane) to run everything, or put
#      your cursor on a line and press Cmd/Ctrl+Enter to run one line at a time
#      (recommended the first time through!).
#
#   THE RESEARCH QUESTION (plain language)
#   Children hear two characters explain a person's quirky behavior:
#     - one refers to them as an INDIVIDUAL  ("Rowan likes to play with bugs")
#     - one refers to them via their GROUP   ("Wugs like to play with bugs")
#   Do children treat the *individual* framing as a cue that the speaker is
#   CLOSE to the person (their best friend), rather than an authority (boss)?
# =============================================================================


## ---------------------------------------------------------------------------
## STEP 0: PACKAGES
## ---------------------------------------------------------------------------
# R's power comes from add-on "packages". library() loads an installed package.
# If any line here errors with "there is no package called ...", run e.g.:
#   install.packages("tidyverse")
library(tidyverse)    # data wrangling (dplyr) + plotting (ggplot2)
library(lubridate)    # easy handling of dates/times
library(brms)         # Bayesian regression models (uses the Stan sampler)
library(bayestestR)   # helpers: probability of direction, ROPE, etc.
library(BayesFactor)  # simple Bayes-factor t-tests

# Make R look for the data files in the folder where THIS script lives.
# (rstudioapi asks RStudio "which file is open?"; works when you press Source.)
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

# Bayesian models involve random sampling; fixing the "seed" makes every run
# give the same numbers, so results are reproducible.
SEED <- 20260731
set.seed(SEED)


## ---------------------------------------------------------------------------
## STEP 1: LOAD AND CLEAN STUDY 1
## ---------------------------------------------------------------------------
# read_csv() loads a spreadsheet into a "data frame": rows = trials here.
s1_raw <- read_csv("twizzle_data.csv", show_col_types = FALSE)

s1 <- s1_raw %>%                                    # %>% means "then do..."
  # Remove test runs by the researchers (they typed "test" as the name):
  filter(!str_detect(str_to_lower(firstName), "test")) %>%
  # Keep the pre-registered age range:
  filter(age >= 5, age <= 8) %>%
  mutate(
    # OUR OUTCOME ("dependent variable"): did the child pick the speaker who
    # explained the behavior at the INDIVIDUAL level? 1 = yes, 0 = no.
    choseInd = as.numeric(chosenRole == "individual"),
    # Exact age in years (from verified birthdates); if missing, use the
    # reported whole-number age + 0.5 (the average of, say, all 6-year-olds).
    age_dec  = coalesce(age_years_used, age + 0.5)
  )

# Study 1 asked TWO questions in separate blocks; keep them separable:
s1_close <- filter(s1, questionType == "close")   # "who is the BEST FRIEND?"
s1_boss  <- filter(s1, questionType == "boss")    # "who is the BOSS?"

# Always eyeball your data before modeling! n_distinct counts unique children.
cat("Study 1:", n_distinct(s1$participantId), "children,", nrow(s1), "trials\n")


## ---------------------------------------------------------------------------
## STEP 2: LOAD AND CLEAN STUDY 2
## ---------------------------------------------------------------------------
s2_raw <- read_csv("study2_data.csv", show_col_types = FALSE)

# Children excluded before analysis (documented in study2_match_ledger.csv):
# one observed pilot child, several sessions with no verifiable parental
# consent record, and two fraudulent sessions flagged on video review.
EXCLUDED <- c(
  "TT009_1785285837662",  # pilot (observed before pre-registration)
  "TT030_1786981806095", "TT048_1786897799066", "TT072_1786982010792",
  "TT007_1787400154701", "TT086_1787401130147", "TT047_1788009524301",
  "TT035_1788184474250", "TT026_1788255831256"
)

s2 <- s2_raw %>%
  filter(study == "study2",
         !str_detect(str_to_lower(participantId), "test"),
         !str_detect(str_to_lower(firstName), "test"),
         !participantId %in% EXCLUDED) %>%
  # A few children accidentally started twice; keep only the FIRST copy of
  # each trial. distinct() keeps one row per unique combination listed:
  mutate(ts = ymd_hms(timestamp)) %>%
  arrange(participantId, ts) %>%
  distinct(participantId, blockIndex, trialInBlock, .keep_all = TRUE) %>%
  filter(age >= 5, age <= 8) %>%
  mutate(
    # In Study 2 both roles were assigned at once (forced choice). The outcome:
    # 1 = the child made the INDIVIDUAL-explainer the BEST FRIEND
    # 0 = the child made the individual-explainer the BOSS
    choseIndividualAsBF = as.numeric(hypothesisConsistent),
    age_dec = coalesce(age_exact, age + 0.5)
  )

cat("Study 2:", n_distinct(s2$participantId), "children,", nrow(s2), "trials\n")


## ---------------------------------------------------------------------------
## STEP 3: DESCRIPTIVE STATISTICS ("what does the data look like?")
## ---------------------------------------------------------------------------
# Each child gave several yes/no answers. To describe children (not trials),
# first compute each child's personal proportion, THEN average those.
per_child <- function(d, dv) {
  d %>%
    group_by(participantId) %>%
    summarise(age = first(age), age_dec = first(age_dec),
              p = mean({{ dv }}), .groups = "drop")
}
pc_s1_close <- per_child(s1_close, choseInd)
pc_s1_boss  <- per_child(s1_boss,  choseInd)
pc_s2       <- per_child(s2,       choseIndividualAsBF)

# Means by whole-year age (0.5 would be "no preference" / coin-flipping):
pc_s2 %>% group_by(age) %>% summarise(mean = mean(p), n = n())


## ---------------------------------------------------------------------------
## STEP 4: SIMPLE TESTS AGAINST CHANCE (Bayes-factor t-tests)
## ---------------------------------------------------------------------------
# QUESTION: is a group of children above 50/50 chance?
# A Bayes factor (BF) compares two explanations of the data:
#     H1 "the true mean is ABOVE 0.5"   vs.   H0 "it is exactly 0.5"
# BF = 10 means the data are 10x more likely under H1 than H0.
# Rules of thumb: BF > 3 modest, > 10 strong, > 100 extreme evidence for H1;
# BF < 1/3 is evidence FOR the null (children really are at chance).
# nullInterval = c(0, Inf) makes the test DIRECTIONAL (we predicted "above").
bf_above_chance <- function(p_values) {
  bf <- ttestBF(x = p_values, mu = 0.5, nullInterval = c(0, Inf))
  extractBF(bf)$bf[1]
}

# Study 2, pre-registered split: older (7-8) vs. younger (5-6) children.
older   <- filter(pc_s2, age >= 7)$p
younger <- filter(pc_s2, age <= 6)$p
cat("Older 7-8:   mean =", round(mean(older), 3),   " BF =", round(bf_above_chance(older), 1),   "\n")
cat("Younger 5-6: mean =", round(mean(younger), 3), " BF =", round(bf_above_chance(younger), 2), "\n")
# Typical result: older children clearly above chance; younger children have a
# BF well below 1/3 -- positive evidence they respond at chance.


## ---------------------------------------------------------------------------
## STEP 5: THE MAIN BAYESIAN MIXED MODEL (Study 2)
## ---------------------------------------------------------------------------
# Why not just t-tests? Because each child contributed 4 related answers.
# A MIXED model handles that: it gives every child their own baseline
# tendency -- the "(1 | participantId)" part, called a RANDOM INTERCEPT --
# so one enthusiastic child can't masquerade as many independent data points.
#
# family = bernoulli() : the outcome is 0/1, so this is LOGISTIC regression.
#   Effects are on the "log-odds" scale: 0 = no effect; +0.5 raises a 50%
#   probability to about 62%.
#
# Predictors (sum-coded as +1/-1 so the intercept = the overall average):
#   epistemic : did the speaker sound uncertain ("Hmm...") or sure ("Yes...")?
#   ageGroup  : younger (5-6) vs. older (7-8)
#
# PRIORS express what effect sizes we considered plausible before the data:
#   normal(0, 1)  : effects near zero most likely, very large ones unlikely.
#   exponential(2): child-to-child variability is modest but can grow if
#                   the data demand it.
s2_model_data <- s2 %>%
  mutate(epistemic_c = ifelse(epistemic == "hmm", 1, -1),
         ageGroup_c  = ifelse(age <= 6, 1, -1))

fit_main <- brm(
  choseIndividualAsBF ~ epistemic_c * ageGroup_c + (1 | participantId),
  data    = s2_model_data,
  family  = bernoulli(),
  prior   = c(prior(normal(0, 1.5), class = Intercept),
              prior(normal(0, 1),   class = b),
              prior(exponential(2), class = sd)),
  chains = 4, iter = 4000, warmup = 1000,
  seed = SEED, control = list(adapt_delta = 0.95)
)

# HOW TO READ THE OUTPUT of summary(fit_main):
#  - "Estimate"  : best guess for each effect (log-odds scale).
#  - "l-95% CI / u-95% CI": the credible interval -- given the model, there is
#    a 95% probability the true effect lies in this range. If the interval
#    excludes 0, we are quite confident about the effect's direction.
#  - Rhat should be 1.00 (the sampler converged; if not, rerun/ask for help).
summary(fit_main)

# Two friendly effect summaries from bayestestR:
#  - pd ("probability of direction"): how sure are we about the SIGN? (0.5-1)
#  - ROPE: % of the posterior inside [-0.18, 0.18], effects so small we would
#    call them negligible. ~0% inside = meaningfully large; most inside = null.
describe_posterior(fit_main, ci = 0.95, rope_ci = 1,
                   rope_range = c(-0.18, 0.18))


## ---------------------------------------------------------------------------
## STEP 6: DOES THE PREFERENCE GROW WITH AGE? (continuous-age model)
## ---------------------------------------------------------------------------
# Same idea, but age enters as a NUMBER (in years, centered so the intercept
# is "an average-aged child") instead of two bins. The slope b_age answers:
# "how much do the log-odds change per year of age?"
s2_model_data <- mutate(s2_model_data, age_c = age_dec - mean(age_dec))
fit_age <- brm(
  choseIndividualAsBF ~ age_c + (1 | participantId),
  data = s2_model_data, family = bernoulli(),
  prior = c(prior(normal(0, 1.5), class = Intercept),
            prior(normal(0, 1),   class = b),
            prior(exponential(2), class = sd)),
  chains = 4, iter = 4000, warmup = 1000, seed = SEED,
  control = list(adapt_delta = 0.95)
)
summary(fit_age)

# The same model can be fit for Study 1's two questions -- try it yourself!
# Replace the data and outcome, e.g.:
#   brm(choseInd ~ age_c + (1 | participantId), data = ..., ...)


## ---------------------------------------------------------------------------
## STEP 7: ONE FIGURE FOR BOTH STUDIES
## ---------------------------------------------------------------------------
# ggplot builds figures in layers: data -> points -> fitted curve -> labels.
# geom_smooth(method="glm", family=binomial) overlays a simple logistic curve
# (a good visual summary; the brms models above are the formal analysis).
plot_panel <- function(d, dv, title, top_lab, bottom_lab) {
  ggplot(d, aes(x = age_dec, y = {{ dv }})) +
    geom_hline(yintercept = 0.5, linetype = 2, alpha = 0.6) +   # chance line
    geom_jitter(width = 0.04, height = 0.05, alpha = 0.2,
                colour = "deepskyblue") +                       # raw trials
    geom_smooth(method = "glm", method.args = list(family = binomial),
                colour = "deepskyblue", fill = "deepskyblue",
                alpha = 0.2, linewidth = 1.6) +                 # fitted curve
    scale_y_continuous(breaks = c(0, 0.5, 1),
                       labels = c(bottom_lab, "0.5", top_lab)) +
    scale_x_continuous(breaks = 5:9) +
    labs(title = title, x = "Age (Years)", y = NULL) +
    theme_minimal(base_size = 15) +
    theme(panel.grid = element_blank(),
          axis.line  = element_line(colour = "black", linewidth = 0.5),
          axis.text  = element_text(colour = "black", face = "bold"))
}

p1 <- plot_panel(s1_close, choseInd, "Study 1: Best-friend question",
                 "Chose Individual\nExplainer", "Chose Group\nExplainer")
p2 <- plot_panel(s1_boss,  choseInd, "Study 1: Boss question",
                 "Chose Individual\nExplainer", "Chose Group\nExplainer")
p3 <- plot_panel(s2, choseIndividualAsBF, "Study 2: Forced choice",
                 "Individual Explainer\nis Best Friend",
                 "Individual Explainer\nis Boss")

# cowplot glues panels side by side. install.packages("cowplot") if needed.
combined <- cowplot::plot_grid(p1, p2, p3, nrow = 1)
combined                                        # displays in the Plots pane
ggsave("figures_ink/s1_s2_threepanel.png", combined,
       width = 16, height = 5, dpi = 300, bg = "white")

# WHAT THE FIGURE SHOWS
# Study 1: children increasingly pick the individual-explainer for BOTH
# questions (best friend AND boss) -- so Study 1 alone cannot tell whether
# they infer closeness or just like that speaker. Study 2 forces the two
# roles to compete: with age, children route the individual-explainer to
# BEST FRIEND specifically. That is the developmental claim of the paper.

message("Done! Models are in fit_main / fit_age; figure saved to figures_ink/.")
