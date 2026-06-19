# =============================================================
#  Twizzle Town — Bayesian analyses (matches preregistration.md)
#  PI: Ashley Thomas, Harvard University
#
#  Implements §6 of the pre-registration:
#    6.1 Primary brms model
#    6.3 Cell-level Bayesian one-sample tests (BayesFactor)
#    6.4 Age-stratified models
#    6.5 Sensitivity analyses (1–4)
#    6.6 Exploratory analyses (separate marker)
#
#  Inputs:
#    twizzle_data.tsv next to this script (same export used by
#    analyze_twizzle.R).
#
#  Outputs (next to this script):
#    figures_bayes/   PNG plots
#    tables_bayes/    summary CSVs
#    fits/            cached brms fits (so re-runs don't refit)
#
#  Heads-up: cold fits take ~30 s – 2 min each on a typical Mac.
#  Subsequent runs reuse cached fits in fits/.
# =============================================================

# ---- 0. Setup ------------------------------------------------
suppressPackageStartupMessages({
  needed <- c("tidyverse", "brms", "bayestestR", "tidybayes",
              "BayesFactor", "scales", "patchwork")
  to_install <- needed[!needed %in% installed.packages()[, "Package"]]
  if (length(to_install)) install.packages(to_install)
  library(tidyverse)
  library(brms)
  library(bayestestR)
  library(tidybayes)
  library(BayesFactor)
  library(scales)
  library(patchwork)
})

options(mc.cores = max(1, parallel::detectCores() - 1),
        brms.backend = "rstan",      # change to "cmdstanr" if installed
        dplyr.summarise.inform = FALSE)

# Resolve paths
this_file <- tryCatch(
  rstudioapi::getSourceEditorContext()$path,
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- sub("--file=", "", args[grep("--file=", args)])
    if (length(file_arg)) file_arg else "analyze_twizzle_bayes.R"
  }
)
SCRIPT_DIR <- normalizePath(dirname(this_file), mustWork = FALSE)
setwd(SCRIPT_DIR)

DATA_PATH <- file.path(SCRIPT_DIR, "twizzle_data.tsv")
if (!file.exists(DATA_PATH)) {
  alt <- c("twizzle_data.csv", "data.tsv", "data.csv",
           "../twizzle_data.tsv", "../twizzle_data.csv")
  hit <- alt[file.exists(file.path(SCRIPT_DIR, alt))][1]
  if (!is.na(hit)) DATA_PATH <- file.path(SCRIPT_DIR, hit)
}
stopifnot("Data file not found." = file.exists(DATA_PATH))

dir.create("figures_bayes", showWarnings = FALSE)
dir.create("tables_bayes",  showWarnings = FALSE)
dir.create("fits",          showWarnings = FALSE)

# ---- 1. Read + clean (matches analyze_twizzle.R) -------------
read_any <- function(p) {
  if (grepl("\\.tsv$|\\.txt$", p, ignore.case = TRUE))
    readr::read_tsv(p, show_col_types = FALSE)
  else if (grepl("\\.csv$", p, ignore.case = TRUE))
    readr::read_csv(p, show_col_types = FALSE)
  else stop("Unknown extension: ", p)
}
raw <- read_any(DATA_PATH)
cat("Loaded", nrow(raw), "rows from", basename(DATA_PATH), "\n")

dat <- raw |>
  mutate(
    participantId         = as.character(participantId),
    firstName             = as.character(firstName),
    age                   = as.numeric(age),
    questionType          = factor(questionType, levels = c("close", "boss")),
    epistemic             = factor(epistemic,    levels = c("hmm",   "yes")),
    chosenRole            = factor(chosenRole,   levels = c("group", "individual")),
    hypothesisConsistent  = as.integer(hypothesisConsistent),
    rt_ms                 = as.numeric(rt_ms),
    timestamp             = suppressWarnings(as.POSIXct(timestamp, tz = "UTC"))
  ) |>
  filter(
    !is.na(participantId),
    !toupper(participantId) %in% c("TEST", "TESTING", "PILOT"),
    !toupper(firstName)     %in% c("TEST", "TESTING", "PILOT")
  ) |>
  arrange(participantId, timestamp) |>
  distinct(participantId, dataExportTag, .keep_all = TRUE)

# Pre-registered age window: 5–8
MIN_AGE <- 5
MAX_AGE <- 8
dat <- dat |> filter(age >= MIN_AGE, age <= MAX_AGE + 0.999)

# Age grouping (pre-reg §6.2: 6yo with younger)
dat <- dat |>
  mutate(
    ageGroup = factor(
      if_else(age < 7, "Younger", "Older"),
      levels = c("Younger", "Older")
    ),
    age_c    = as.numeric(scale(age, center = TRUE, scale = FALSE))
  )

cat("\nIncluded participants:", n_distinct(dat$participantId),
    " | trials:", nrow(dat), "\n")
cat("Age-group counts (participants):\n")
print(dat |> distinct(participantId, ageGroup) |> count(ageGroup))

# Sum-coded contrasts (per pre-reg §6.1)
contrasts(dat$questionType) <- contr.sum(2); colnames(contrasts(dat$questionType)) <- "boss_vs_close"
contrasts(dat$epistemic)    <- contr.sum(2); colnames(contrasts(dat$epistemic))    <- "yes_vs_hmm"
contrasts(dat$ageGroup)     <- contr.sum(2); colnames(contrasts(dat$ageGroup))     <- "older_vs_younger"

# ---- 2. Pre-registered priors (§6.1) -------------------------
priors_main <- c(
  prior(normal(0, 1.5), class = "Intercept"),
  prior(normal(0, 1),   class = "b"),
  prior(exponential(2), class = "sd")
)

# Helper that caches fits by name so re-running this script is fast.
# Default family is bernoulli (matches primary analysis); pass family=...
# to override (e.g. for the RT model).
fit_cached <- function(name, formula, data, prior,
                       family = bernoulli(), ...,
                       refit = FALSE) {
  path <- file.path("fits", paste0(name, ".rds"))
  if (!refit && file.exists(path)) {
    cat("  loading cached fit:", name, "\n")
    return(readRDS(path))
  }
  cat("  fitting:", name, "...\n")
  fit <- brm(
    formula = formula, data = data, prior = prior,
    family  = family,
    iter    = 4000, warmup = 1000, chains = 4,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    save_pars = save_pars(all = TRUE),
    seed    = 20260619,
    silent  = 2, refresh = 0,
    ...
  )
  saveRDS(fit, path)
  fit
}

# ---- 3. §6.1 Primary model -----------------------------------
cat("\n=== §6.1 Primary brms model ===\n")
m_main <- fit_cached(
  "m_main",
  hypothesisConsistent ~ questionType * epistemic * ageGroup
                       + (1 + questionType + epistemic | participantId),
  data  = dat,
  prior = priors_main
)
print(summary(m_main))

# Posterior summaries: 95% CrI, P(direction)
post_main <- bayestestR::describe_posterior(
  m_main,
  ci         = 0.95, ci_method = "hdi",
  test       = c("pd", "rope"),
  rope_range = c(-0.18, 0.18)   # ~equivalent to OR in [0.84, 1.20] — small effect
)
print(post_main)
write_csv(as_tibble(post_main), "tables_bayes/m_main_posterior.csv")

# Savage–Dickey Bayes factors against zero for each population-level coefficient
bf_main <- bayestestR::bayesfactor_parameters(m_main, null = 0)
print(bf_main)
write_csv(as_tibble(bf_main), "tables_bayes/m_main_bayes_factors.csv")

# ---- 4. §6.3 Cell-level Bayesian chance tests ----------------
cat("\n=== §6.3 Cell-level Bayesian one-sample tests vs 0.5 ===\n")
pp <- dat |>
  group_by(participantId, ageGroup, questionType, epistemic) |>
  summarise(p_hypothesis = mean(hypothesisConsistent),
            n_trials     = n(), .groups = "drop")
write_csv(pp, "tables_bayes/per_participant_cell_means.csv")

cell_tests <- pp |>
  group_by(questionType, epistemic) |>
  summarise(
    n             = n(),
    mean_p        = mean(p_hypothesis),
    bf_directional = {
      x <- p_hypothesis
      if (length(x) > 2 && sd(x) > 0) {
        bf <- BayesFactor::ttestBF(x, mu = 0.5, nullInterval = c(0.5, 1))
        as.numeric(BayesFactor::extractBF(bf)$bf[1])
      } else NA_real_
    },
    .groups = "drop"
  )
print(cell_tests)
write_csv(cell_tests, "tables_bayes/chance_tests_per_cell.csv")

# Same thing within each age group
cell_tests_by_age <- pp |>
  group_by(ageGroup, questionType, epistemic) |>
  summarise(
    n              = n(),
    mean_p         = mean(p_hypothesis),
    bf_directional = {
      x <- p_hypothesis
      if (length(x) > 2 && sd(x) > 0) {
        bf <- BayesFactor::ttestBF(x, mu = 0.5, nullInterval = c(0.5, 1))
        as.numeric(BayesFactor::extractBF(bf)$bf[1])
      } else NA_real_
    },
    .groups = "drop"
  )
print(cell_tests_by_age)
write_csv(cell_tests_by_age, "tables_bayes/chance_tests_by_age.csv")

# ---- 5. §6.4 Age-stratified models ---------------------------
cat("\n=== §6.4 Age-stratified models ===\n")
m_younger <- fit_cached(
  "m_younger",
  hypothesisConsistent ~ questionType * epistemic
                       + (1 + questionType + epistemic | participantId),
  data  = filter(dat, ageGroup == "Younger"),
  prior = priors_main
)
m_older <- fit_cached(
  "m_older",
  hypothesisConsistent ~ questionType * epistemic
                       + (1 + questionType + epistemic | participantId),
  data  = filter(dat, ageGroup == "Older"),
  prior = priors_main
)
for (nm in c("m_younger", "m_older")) {
  cat("\n---", nm, "---\n")
  print(summary(get(nm)))
  d <- bayestestR::describe_posterior(get(nm), ci = 0.95, ci_method = "hdi",
                                       test = c("pd"))
  write_csv(as_tibble(d), paste0("tables_bayes/", nm, "_posterior.csv"))
}

# ---- 6. §6.5 Sensitivity analyses ----------------------------
cat("\n=== §6.5 Sensitivity analyses ===\n")

# 6.5.1 Continuous age
m_sens_age <- fit_cached(
  "m_sens_age_continuous",
  hypothesisConsistent ~ questionType * epistemic * age_c
                       + (1 + questionType + epistemic | participantId),
  data = dat, prior = priors_main
)
cat("\n[6.5.1 Continuous age]\n"); print(summary(m_sens_age))
write_csv(as_tibble(bayestestR::describe_posterior(m_sens_age, test = "pd")),
          "tables_bayes/m_sens_age_continuous_posterior.csv")

# 6.5.2a Tighter priors
priors_tight <- c(
  prior(normal(0, 1.5), class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  prior(exponential(2), class = "sd")
)
m_sens_tight <- fit_cached(
  "m_sens_priors_tight",
  hypothesisConsistent ~ questionType * epistemic * ageGroup
                       + (1 + questionType + epistemic | participantId),
  data = dat, prior = priors_tight
)
write_csv(as_tibble(bayestestR::describe_posterior(m_sens_tight, test = "pd")),
          "tables_bayes/m_sens_priors_tight_posterior.csv")

# 6.5.2b Wider priors
priors_wide <- c(
  prior(normal(0, 1.5), class = "Intercept"),
  prior(normal(0, 2.5), class = "b"),
  prior(exponential(2), class = "sd")
)
m_sens_wide <- fit_cached(
  "m_sens_priors_wide",
  hypothesisConsistent ~ questionType * epistemic * ageGroup
                       + (1 + questionType + epistemic | participantId),
  data = dat, prior = priors_wide
)
write_csv(as_tibble(bayestestR::describe_posterior(m_sens_wide, test = "pd")),
          "tables_bayes/m_sens_priors_wide_posterior.csv")

# 6.5.3 Trial-count threshold (only kids who finished all 12)
ids12 <- dat |> count(participantId) |> filter(n == 12) |> pull(participantId)
if (length(ids12) >= 10) {
  m_sens_complete <- fit_cached(
    "m_sens_complete_only",
    hypothesisConsistent ~ questionType * epistemic * ageGroup
                         + (1 + questionType + epistemic | participantId),
    data  = filter(dat, participantId %in% ids12),
    prior = priors_main
  )
  write_csv(as_tibble(bayestestR::describe_posterior(m_sens_complete, test = "pd")),
            "tables_bayes/m_sens_complete_only_posterior.csv")
} else {
  cat("Skipping complete-only sensitivity (n < 10 kids finished all 12).\n")
}

# 6.5.4 6-year-olds with the older group
dat_alt <- dat |>
  mutate(ageGroup = factor(
    if_else(age < 6, "Younger", "Older"),    # 5 vs 6+
    levels = c("Younger", "Older")
  ))
contrasts(dat_alt$ageGroup) <- contr.sum(2)
colnames(contrasts(dat_alt$ageGroup)) <- "older_vs_younger"
m_sens_6older <- fit_cached(
  "m_sens_6_with_older",
  hypothesisConsistent ~ questionType * epistemic * ageGroup
                       + (1 + questionType + epistemic | participantId),
  data = dat_alt, prior = priors_main
)
write_csv(as_tibble(bayestestR::describe_posterior(m_sens_6older, test = "pd")),
          "tables_bayes/m_sens_6_with_older_posterior.csv")

# ---- 7. §6.6 Exploratory analyses ----------------------------
cat("\n=== §6.6 Exploratory ===\n")

# RT model: log-RT ~ questionType * epistemic * ageGroup, gaussian on log scale.
# log(rt_ms) is roughly 9 for ~8-second responses; priors set accordingly.
dat_rt <- dat |>
  filter(rt_ms > 500, rt_ms < 90000) |>
  mutate(log_rt = log(rt_ms))
priors_rt <- c(
  prior(normal(9, 2),   class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  prior(exponential(2), class = "sd"),
  prior(exponential(2), class = "sigma")
)
m_rt <- fit_cached(
  "m_rt_exploratory",
  log_rt ~ questionType * epistemic * ageGroup + (1 | participantId),
  data   = dat_rt,
  prior  = priors_rt,
  family = gaussian()
)

# Item-level random intercepts (sensitivity to specific characters)
m_item <- fit_cached(
  "m_item_random",
  hypothesisConsistent ~ questionType * epistemic * ageGroup
                       + (1 + questionType + epistemic | participantId)
                       + (1 | target),
  data  = dat, prior = priors_main
)

# Counterbalancing nuisance variables
m_nuisance <- fit_cached(
  "m_nuisance_checks",
  hypothesisConsistent ~ questionType * epistemic * ageGroup
                       + rolesSwapped + blockOrder + versionThisBlock
                       + (1 + questionType + epistemic | participantId),
  data  = dat, prior = priors_main
)

# ---- 8. Plots ------------------------------------------------
theme_set(theme_minimal(base_size = 12) +
            theme(strip.background = element_blank(),
                  panel.grid.minor = element_blank()))

# 8a. Cell means with 95% CIs over per-participant proportions
cell_summary <- pp |>
  group_by(questionType, epistemic) |>
  summarise(n_participants = n(),
            mean_p = mean(p_hypothesis),
            sd_p   = sd(p_hypothesis),
            se_p   = sd_p / sqrt(n_participants),
            ci_lo  = mean_p - 1.96 * se_p,
            ci_hi  = mean_p + 1.96 * se_p, .groups = "drop")

p_cells <- ggplot(cell_summary,
                  aes(x = epistemic, y = mean_p, fill = questionType)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey60") +
  geom_col(position = position_dodge(width = 0.7), width = 0.6, alpha = 0.85) +
  geom_errorbar(aes(ymin = pmax(0, ci_lo), ymax = pmin(1, ci_hi)),
                width = 0.18, position = position_dodge(width = 0.7)) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, 1.05), breaks = seq(0, 1, 0.25)) +
  scale_fill_manual(values = c(close = "#3498db", boss = "#e67e22")) +
  labs(title = "Hypothesis-consistent responding",
       x = "Epistemic certainty", y = NULL, fill = "Question")
ggsave("figures_bayes/01_cell_means.png", p_cells, width = 7, height = 4.5, dpi = 200)

# 8b. Same cell means split by age group
cell_summary_age <- pp |>
  group_by(ageGroup, questionType, epistemic) |>
  summarise(n_participants = n(),
            mean_p = mean(p_hypothesis),
            sd_p   = sd(p_hypothesis),
            se_p   = sd_p / sqrt(n_participants),
            ci_lo  = mean_p - 1.96 * se_p,
            ci_hi  = mean_p + 1.96 * se_p, .groups = "drop")

p_cells_age <- ggplot(cell_summary_age,
                      aes(x = epistemic, y = mean_p, fill = questionType)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey60") +
  geom_col(position = position_dodge(width = 0.7), width = 0.6, alpha = 0.85) +
  geom_errorbar(aes(ymin = pmax(0, ci_lo), ymax = pmin(1, ci_hi)),
                width = 0.18, position = position_dodge(width = 0.7)) +
  facet_wrap(~ ageGroup) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, 1.05), breaks = seq(0, 1, 0.25)) +
  scale_fill_manual(values = c(close = "#3498db", boss = "#e67e22")) +
  labs(title = "Hypothesis-consistent responding by age group",
       subtitle = "Younger = 5–6 yrs; Older = 7–8 yrs",
       x = "Epistemic certainty", y = NULL, fill = "Question")
ggsave("figures_bayes/02_cell_means_by_agegroup.png",
       p_cells_age, width = 9, height = 4.5, dpi = 200)

# 8c. Posterior intervals from the primary model
post_draws <- m_main |>
  spread_draws(`b_.*`, regex = TRUE) |>
  pivot_longer(starts_with("b_"), names_to = "term", values_to = "estimate") |>
  filter(term != "b_Intercept")

p_post <- ggplot(post_draws, aes(x = estimate, y = fct_rev(term))) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey60") +
  stat_pointinterval(.width = c(0.66, 0.95), point_size = 2.5, color = "#2c3e50") +
  labs(title = "Posterior distributions (primary model)",
       subtitle = "Log-odds scale; thick = 66% CrI, thin = 95% CrI",
       x = "Posterior estimate (log-odds)", y = NULL)
ggsave("figures_bayes/03_posteriors_primary.png", p_post,
       width = 7, height = 4.5, dpi = 200)

# 8d. Posterior-predicted cell probabilities on the original scale
new_grid <- expand_grid(
  questionType = c("close", "boss"),
  epistemic    = c("hmm", "yes"),
  ageGroup     = c("Younger", "Older")
) |> mutate(across(everything(), as.factor))

pp_pred <- new_grid |>
  add_epred_draws(m_main, re_formula = NA) |>
  group_by(questionType, epistemic, ageGroup) |>
  median_qi(.epred, .width = c(0.95))

p_pred <- ggplot(pp_pred,
                 aes(x = epistemic, y = .epred,
                     ymin = .lower, ymax = .upper,
                     color = questionType, group = questionType)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey60") +
  geom_pointrange(position = position_dodge(width = 0.4), size = 0.6) +
  facet_wrap(~ ageGroup) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  scale_color_manual(values = c(close = "#3498db", boss = "#e67e22")) +
  labs(title = "Posterior predicted cell probabilities (primary model)",
       subtitle = "Bars = 95% CrI",
       x = "Epistemic certainty", y = "P(hypothesis-consistent)", color = "Question")
ggsave("figures_bayes/04_posterior_predicted.png", p_pred,
       width = 9, height = 4.5, dpi = 200)

cat("\nAll done.\n")
cat("Fits cached in:    ", file.path(SCRIPT_DIR, "fits"),         "\n")
cat("Figures saved to:  ", file.path(SCRIPT_DIR, "figures_bayes"),"\n")
cat("Tables  saved to:  ", file.path(SCRIPT_DIR, "tables_bayes"), "\n")
