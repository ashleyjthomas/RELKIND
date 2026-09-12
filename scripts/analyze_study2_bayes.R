# ============================================================================
#  analyze_study2_bayes.R - main analysis script for RELKIND Study 2
#  "Children's Inferences About Relationships From The Way People Explain
#   Behavior. Study 2" (OSF registration: https://osf.io/9ztu7)
#
#  This script:
#    - loads the Study 2 game export (study2_data.csv, next to this script)
#    - applies the pre-registered inclusion/exclusion rules (TEST + pilot
#      sessions out, duplicate sessions -> first session kept)
#    - fits the pre-registered Bayesian mixed-effects models
#      (saved to results/study2/models/*.rds so re-runs don't refit)
#    - produces the bar plot, developmental (age) plot, and per-age-year
#      estimates, plus CSV tables for the manuscript
#
#  DV CODING (everywhere): choseIndividualAsBF = 1 if the child assigned the
#  INDIVIDUAL-level explainer to the BEST-FRIEND role (and therefore the
#  group-level explainer to the boss role); 0 if the reverse.
#
#  DESIGN: 2 epistemic frames (Hmm / Yes), blocked, 2 trials per block =
#  4 trials per child. No question-type factor: every trial is a joint
#  assignment of both roles.
#
#  INPUTS
#    study2_data.csv        the Google-Sheet export (Data tab), all columns
#    study2_exact_ages.csv  OPTIONAL: participantId, age_exact (years, from
#                           CHS birthdates). If absent, age + 0.5 is used.
#
#  Pre-registration: study2/preregistration_study2.md ; §6 numbering below
#  matches that document.
# ============================================================================


# SETUP ----

## Packages ----

ipak <- function(pkg) {
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

packages <- c(
  "tidyverse", "brms", "bayestestR", "tidybayes", "BayesFactor",
  "emmeans", "cowplot", "scales", "stringr", "readr", "lubridate"
)
ipak(packages)


## Paths (script-relative; works without an .Rproj) ----

SCRIPT_DIR <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    fa <- sub("--file=", "", args[grep("--file=", args)])
    if (length(fa)) dirname(normalizePath(fa)) else "."
  }
)
setwd(SCRIPT_DIR)

DATA_PATH  <- file.path(SCRIPT_DIR, "study2_data.csv")
AGES_PATH  <- file.path(SCRIPT_DIR, "study2_exact_ages.csv")   # optional
results_dir <- file.path(SCRIPT_DIR, "results", "study2")
models_dir  <- file.path(results_dir, "models")
fig_dir     <- file.path(results_dir, "figures")
for (d in c(models_dir, fig_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

stopifnot("study2_data.csv not found next to this script." = file.exists(DATA_PATH))

# Sessions the authors OBSERVED before registration (07/31/2026 11:02 AM) are
# pilot per the pre-registration; everything else in the export is confirmatory.
PILOT_PIDS <- c("TT009_1785285837662")   # "max" — flagged PILOT in the sheet

# Excluded per the pre-registered consent criterion (no verifiable CHS
# consent record; see study2_match_ledger.csv):
EXCLUDED_PIDS <- c(
  "TT030_1786981806095",   # "IAN"  (8) - no verifiable CHS consent record
  "TT048_1786897799066",   # "arlo" (7) - consent recorded only 4 days post-session
  "TT072_1786982010792",   # "Tina" (8) - no CHS record (sibling of consented child)
  "TT007_1787400154701",   # "Ruth" (7) - no CHS record; incomplete
  "TT086_1787401130147",   # "Joy"  (4) - no CHS record; incomplete
  "TT047_1788009524301",   # "Pearl"(5) - no CHS record; incomplete
  "TT035_1788184474250",   # "alex" (6) - flagged fraudulent CHS session (Aug 31)
  "TT026_1788255831256"    # "Ruth" (6) - flagged fraudulent CHS session (Sep 1)
)


## Shared palette ----

okabe_ito <- c(
  "#000000", "#E69F00", "#56B4E9",
  "#009E73", "#F0E442", "#0072B2",
  "#D55E00", "#CC79A7"
)

# epistemic condition colours (bars + age lines)
cond_cols <- c(Hmm = "#0072B2", Yes = "#D55E00")

# fill scheme for the forced-choice bars (boss-assignment grey, BF coloured)
s2_fills <- c(
  "Individual = boss"        = "grey80",
  "Individual = best friend (Hmm)" = "#0072B2",
  "Individual = best friend (Yes)" = "#D55E00"
)


## Priors (pre-registered, §6.1; tight/wide are the §6.5 sensitivity set) ----

priors_main <- c(
  prior(normal(0, 1.5), class = "Intercept"),
  prior(normal(0, 1),   class = "b"),
  prior(exponential(2), class = "sd")
)
priors_tight <- c(
  prior(normal(0, 1.5), class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  prior(exponential(2), class = "sd")
)
priors_wide <- c(
  prior(normal(0, 1.5), class = "Intercept"),
  prior(normal(0, 2.5), class = "b"),
  prior(exponential(2), class = "sd")
)


## Shared helper functions ----

as01 <- function(x) suppressWarnings(as.integer(round(as.numeric(x))))

# ALWAYS refit and overwrite the saved .rds (never load from disk), so the
# models can never be stale relative to the data. The .rds files are still
# written for the manuscript to read. If fitting ever gets slow enough to
# hurt (~1-2 min per model), flip ALWAYS_REFIT to FALSE to reuse caches —
# but then remember to delete results/study2/models/ whenever the data change.
ALWAYS_REFIT <- TRUE
fit_or_load <- function(file, fit_fun) {
  path <- file.path(models_dir, file)
  if (!ALWAYS_REFIT && file.exists(path)) return(readRDS(path))
  m <- fit_fun()
  saveRDS(m, path)
  m
}

# standard brms call (pre-registered: Bayesian hierarchical LOGISTIC regression)
brm_std <- function(formula, data, prior = priors_main, adapt_delta = 0.95) {
  brm(formula, data = data, family = bernoulli(),
      prior = prior, save_pars = save_pars(all = TRUE),
      iter = 4000, warmup = 1000, chains = 4,
      cores = 4, seed = 20260731, refresh = 0,
      control = list(adapt_delta = adapt_delta))
}

# ONE-SIDED Bayesian one-sample t test of per-participant proportions vs .5
# (pre-registered §6.3: ttestBF, nullInterval = c(0, Inf)). Returns BF+0.
bf_chance <- function(p) {
  p <- p[!is.na(p)]
  if (length(p) < 3 || sd(p) == 0) return(NA_real_)
  bf <- BayesFactor::ttestBF(x = p, mu = 0.5, nullInterval = c(0, Inf))
  as.numeric(as.vector(bf))[1]
}

# per-cell summary over per-participant proportions: mean, n, directional BF
cell_summary <- function(dat, ...) {
  grp <- rlang::enquos(...)
  dat %>%
    dplyr::group_by(participantId, !!!grp) %>%
    dplyr::summarise(p = mean(choseIndividualAsBF), .groups = "drop") %>%
    dplyr::group_by(!!!grp) %>%
    dplyr::summarise(
      n      = dplyr::n(),
      mean_p = round(mean(p), 3),
      BF10   = round(bf_chance(p), 2),
      BF01   = round(1 / BF10, 2),
      .groups = "drop"
    )
}

# shared ggplot theme (OMIT house style)
theme_study <- function() {
  theme_minimal(base_size = 18, base_family = "Avenir Next") +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.spacing      = unit(1.6, "lines"),
      axis.line          = element_line(colour = "black", linewidth = 0.6),
      axis.ticks         = element_line(colour = "black"),
      axis.text          = element_text(colour = "black", face = "bold"),
      legend.position    = "bottom",
      plot.title         = element_text(size = 18, face = "bold"),
      strip.text         = element_text(size = 14, face = "bold")
    )
}

# significance stars from a one-sided BF (vs chance, hypothesis direction)
bf_star <- function(bf) dplyr::case_when(is.na(bf) ~ "", bf >= 100 ~ "***",
                                         bf >= 10 ~ "**", bf >= 3 ~ "*",
                                         TRUE ~ "")

# posterior median / 95% CI / pd for one model -> tidy rows
tidy_post <- function(model, name) {
  dp <- describe_posterior(model, ci = .95, rope_range = c(-0.18, 0.18),
                           rope_ci = 1, test = c("rope", "pd"))
  as.data.frame(dp) %>%
    transmute(model = name, term = Parameter,
              median = round(Median, 2), CI_low = round(CI_low, 2),
              CI_high = round(CI_high, 2),
              pct_in_ROPE = round(100 * ROPE_Percentage, 1), pd = round(pd, 3))
}


# DATA ----

raw <- readr::read_csv(DATA_PATH, show_col_types = FALSE)

# Rows exported before the DV rename lack the choseIndividualAsBF column;
# the legacy alias hypothesisConsistent carries identical values (post-reg
# note 1). Build the DV here, OUTSIDE the pipeline, so the code runs whether
# or not the sheet has the new column yet.
dv_new <- if ("choseIndividualAsBF" %in% names(raw)) {
  as01(raw$choseIndividualAsBF)
} else {
  rep(NA_integer_, nrow(raw))
}
raw$choseIndividualAsBF <- dplyr::coalesce(dv_new, as01(raw$hypothesisConsistent))

dat <- raw %>%
  dplyr::filter(study == "study2") %>%
  dplyr::mutate(
    participantId = as.character(participantId),
    timestamp     = suppressWarnings(lubridate::ymd_hms(timestamp))
  ) %>%
  # TEST sessions (any id/name containing "test") and observed-pilot sessions out
  dplyr::filter(
    !grepl("test", participantId, ignore.case = TRUE),
    !grepl("test", firstName,     ignore.case = TRUE),
    !participantId %in% c(PILOT_PIDS, EXCLUDED_PIDS)
  ) %>%
  dplyr::mutate(
    age       = as.numeric(age),
    epistemic = factor(epistemic, levels = c("hmm", "yes"),
                       labels = c("Hmm", "Yes"))
  ) %>%
  dplyr::filter(!is.na(choseIndividualAsBF)) %>%   # drop any malformed rows
  # Duplicate sessions (same participantId re-run, e.g. a sibling on the same
  # link): keep the FIRST session = first occurrence of each block/trial slot.
  dplyr::arrange(participantId, timestamp) %>%
  dplyr::distinct(participantId, blockIndex, trialInBlock, .keep_all = TRUE)

# exact age (years) from CHS birthdates where available; else age + 0.5.
# Preference order: an age_exact column already merged into study2_data.csv >
# the side file study2_exact_ages.csv > caregiver age + 0.5.
if (!"age_exact" %in% names(dat)) {
  if (file.exists(AGES_PATH)) {
    ages <- readr::read_csv(AGES_PATH, show_col_types = FALSE)
    dat  <- dplyr::left_join(dat, ages, by = "participantId")
  } else {
    message("no exact ages found - using caregiver age + 0.5 throughout.")
    dat$age_exact <- NA_real_
  }
}
dat <- dat %>%
  dplyr::mutate(age_exact = as.numeric(age_exact),
                age_best  = dplyr::coalesce(age_exact, age + 0.5))

# Freeze the full cleaned frame BEFORE any age filtering, so re-running any
# part of the script in the same session can never lose the 4-year-olds
# (dat is overwritten below; dat_clean never is).
dat_clean <- dat

# confirmatory sample = ages 5-8 ; 4-year-olds kept separately (exploratory)
d4  <- dplyr::filter(dat_clean, age == 4)
dat <- dplyr::filter(dat_clean, age >= 5, age <= 8)

# age grouping (§6.2) + sum coding (so the intercept = grand-mean log-odds and
# H1 is tested by the intercept)
dat <- dat %>%
  dplyr::mutate(
    ageGroup = factor(ifelse(age_best < 7, "Younger", "Older"),
                      levels = c("Younger", "Older")),
    age_c    = age_best - mean(age_best),
    participantId = factor(participantId)
  )
contrasts(dat$epistemic) <- contr.sum(2); colnames(contrasts(dat$epistemic)) <- "hmm_vs_yes"
contrasts(dat$ageGroup)  <- contr.sum(2); colnames(contrasts(dat$ageGroup))  <- "younger_vs_older"

cat("Included:", dplyr::n_distinct(dat$participantId), "children,",
    nrow(dat), "trials\n")
print(dat %>% dplyr::distinct(participantId, .keep_all = TRUE) %>%
        dplyr::count(floor(age_best)))


# §6.3 CELL-LEVEL CHANCE TESTS (per-participant proportions, BF+0) ----

cell_overall   <- cell_summary(dat)                      # collapsed
cell_epistemic <- cell_summary(dat, epistemic)           # per epistemic cell
cell_age       <- cell_summary(dat, ageGroup)            # per age group
cell_age_epi   <- cell_summary(dat, ageGroup, epistemic) # stratified
print(cell_overall); print(cell_epistemic); print(cell_age_epi)
readr::write_csv(dplyr::bind_rows(
    dplyr::mutate(cell_overall,   cell = "overall"),
    dplyr::mutate(cell_epistemic, cell = "epistemic"),
    dplyr::mutate(cell_age,       cell = "ageGroup"),
    dplyr::mutate(cell_age_epi,   cell = "ageGroup_x_epistemic")),
  file.path(results_dir, "chance_tests.csv"))


# §6.1 PRIMARY CONFIRMATORY MODEL ----
# H1 = intercept (> 0); H2 = ageGroup coefficient (+ continuous model, §6.5)

xfit_main <- fit_or_load("s2_main.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * ageGroup + (1 | participantId), dat))
print(summary(xfit_main))
rope(xfit_main); conditional_effects(xfit_main)


# §6.4 AGE-STRATIFIED MODELS ----

xfit_young <- fit_or_load("s2_younger.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic + (1 | participantId),
          dplyr::filter(dat, ageGroup == "Younger")))
xfit_old <- fit_or_load("s2_older.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic + (1 | participantId),
          dplyr::filter(dat, ageGroup == "Older")))


# §6.5 SENSITIVITY ANALYSES ----

# 1. continuous (exact) age
xfit_age <- fit_or_load("s2_age_continuous.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * age_c + (1 | participantId), dat))
# 2. prior sensitivity
xfit_tight <- fit_or_load("s2_priors_tight.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * ageGroup + (1 | participantId),
          dat, prior = priors_tight))
xfit_wide <- fit_or_load("s2_priors_wide.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * ageGroup + (1 | participantId),
          dat, prior = priors_wide))
# 3. complete sessions only (all 4 trials)
ids4 <- dat %>% dplyr::count(participantId) %>%
  dplyr::filter(n == 4) %>% dplyr::pull(participantId)
xfit_complete <- fit_or_load("s2_complete_only.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * ageGroup + (1 | participantId),
          dplyr::filter(dat, participantId %in% ids4)))
# 4. 6-year-olds grouped with the older children
dat_alt <- dat %>%
  dplyr::mutate(ageGroup = factor(ifelse(age_best < 6, "Younger", "Older"),
                                  levels = c("Younger", "Older")))
contrasts(dat_alt$ageGroup) <- contr.sum(2)
colnames(contrasts(dat_alt$ageGroup)) <- "younger_vs_older"
xfit_6older <- fit_or_load("s2_6_with_older.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * ageGroup + (1 | participantId), dat_alt))


# §6.6 EXPLORATORY (not confirmatory) ----

# log-RT (trials 500 ms - 90 s), gaussian on the log scale
dat_rt <- dat %>% dplyr::filter(rt_ms > 500, rt_ms < 90000) %>%
  dplyr::mutate(log_rt = log(rt_ms))
xfit_rt <- fit_or_load("s2_rt.rds", function()
  brm(log_rt ~ epistemic * ageGroup + (1 | participantId), data = dat_rt,
      family = gaussian(),
      prior = c(prior(normal(10, 2), class = "Intercept"),
                prior(normal(0, 0.5), class = "b"),
                prior(exponential(2), class = "sd"),
                prior(exponential(2), class = "sigma")),
      iter = 4000, warmup = 1000, chains = 4, cores = 4,
      seed = 20260731, refresh = 0, control = list(adapt_delta = 0.95)))

# item (target character) random intercepts
xfit_item <- fit_or_load("s2_item.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * ageGroup + (1 | participantId) +
            (1 | target), dat))

# counterbalancing nuisance variables + trial order (transparency only)
xfit_nuis <- fit_or_load("s2_nuisance.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * ageGroup + rolesSwapped +
            blockOrder + trialInBlock + (1 | participantId), dat))
rope(xfit_nuis)
# 4-year-olds, descriptively
if (nrow(d4) > 0) print(cell_summary(d4))

# exploratory continuous-age model over the FULL 4-8 range (feeds the age
# plot below so the exploratory 4-year-olds appear alongside the
# confirmatory sample; the confirmatory age model remains xfit_age, 5-8 only)
dat_all <- dplyr::bind_rows(dat, d4) %>%
  dplyr::mutate(age_c_all = age_best - mean(age_best),
                participantId = factor(participantId))
contrasts(dat_all$epistemic) <- contr.sum(2)
colnames(contrasts(dat_all$epistemic)) <- "hmm_vs_yes"
xfit_age_all <- fit_or_load("s2_age_continuous_4to8.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * age_c_all + (1 | participantId),
          dat_all))

# why-answers -> one file for qualitative coding (child, age, trial, choice)
why_tbl <- dat %>%
  dplyr::filter(!is.na(whyAnswer), whyAnswer != "") %>%
  dplyr::select(participantId, age_best, epistemic, target,
                choseIndividualAsBF, whyAnswer, why_rt_ms)
readr::write_csv(why_tbl, file.path(results_dir, "why_answers_for_coding.csv"))


# FIGURES ----

## Bar plot: % individual->best-friend by epistemic cell, stars = BF+0 ----

bar_cell <- dat %>%
  dplyr::group_by(participantId, epistemic) %>%
  dplyr::summarise(p = mean(choseIndividualAsBF), .groups = "drop") %>%
  dplyr::group_by(epistemic) %>%
  dplyr::summarise(prop = mean(p), n = dplyr::n(),
                   star = bf_star(bf_chance(p)), .groups = "drop")

bars <- bar_cell %>%
  dplyr::mutate(boss = 1 - prop) %>%
  tidyr::pivot_longer(c(prop, boss), names_to = "choice", values_to = "value") %>%
  dplyr::mutate(fill_group = factor(dplyr::case_when(
    choice == "boss"   ~ "Individual = boss",
    epistemic == "Hmm" ~ "Individual = best friend (Hmm)",
    TRUE               ~ "Individual = best friend (Yes)"),
    levels = names(s2_fills)))

p_bars <- ggplot(bars, aes(epistemic, value, fill = fill_group)) +
  geom_col(width = 0.8, colour = "black", linewidth = 1.1) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "black",
             linewidth = 0.6) +
  geom_text(data = bar_cell, aes(epistemic, 1.02, label = star),
            inherit.aes = FALSE, vjust = 0, size = 6, fontface = "bold") +
  scale_fill_manual(values = s2_fills, name = NULL) +
  scale_y_continuous(breaks = c(0, .25, .5, .75, 1),
                     labels = c("0", "25", "50", "75", "100"),
                     expand = expansion(mult = c(0, 0.09))) +
  coord_cartesian(clip = "off") +
  labs(title = "CHILDREN", x = "Epistemic frame", y = "% of assignments") +
  theme_study() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 16,
                                  margin = margin(b = 6)))
ggsave(file.path(fig_dir, "study2_bars.png"), p_bars,
       width = 6, height = 6, dpi = 300, bg = "white")

## Developmental (age) plot: model-predicted P over exact age + raw jitter ----
# Curve + points span the FULL tested range (4-8; 4-year-olds exploratory,
# from xfit_age_all). The dotted vertical line marks the lower bound of the
# pre-registered confirmatory window (5.0 years).

m_age_all <- mean(dat_all$age_best)
ce <- dplyr::bind_rows(lapply(levels(dat_all$epistemic), function(e) {
  d <- as.data.frame(conditional_effects(
    xfit_age_all, effects = "age_c_all",
    conditions = data.frame(epistemic = factor(e, levels = levels(dat_all$epistemic))))[[1]])
  d$epistemic <- e
  d
})) %>%
  dplyr::mutate(age = age_c_all + m_age_all,
                epistemic = factor(epistemic, levels = c("Hmm", "Yes")))

p_age <- ggplot(ce, aes(age, estimate__, colour = epistemic, fill = epistemic)) +
  geom_jitter(data = dat_all, inherit.aes = FALSE,
              aes(age_best, choseIndividualAsBF, colour = epistemic),
              width = 0.05, height = 0.03, alpha = 0.3, size = 1.5) +
  annotate("text", x = 4.95, y = 0.04, label = "pre-registered window →",
           hjust = 1, size = 3, colour = "grey40") +
  geom_ribbon(aes(ymin = lower__, ymax = upper__), alpha = 0.2, colour = NA) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey40") +
  scale_colour_manual(values = cond_cols, name = "Epistemic frame",
                      aesthetics = c("colour", "fill")) +
  scale_y_continuous(labels = scales::percent, breaks = c(0, .5, 1)) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(title = stringr::str_wrap(
         "Study 2: individual-explainer assigned to best friend, by age (4s exploratory)", 44),
       x = "Age (years)", y = "P(individual = best friend)") +
  theme_study() +
  theme(panel.grid.major.y = element_line(colour = "grey90"),
        plot.title = element_text(size = 14, face = "bold", hjust = 0,
                                  margin = margin(b = 8)),
        plot.title.position = "plot",
        legend.key.width = unit(1.4, "cm"))
ggsave(file.path(fig_dir, "age_study2.png"), p_age,
       width = 6, height = 5, dpi = 300, bg = "white")

## Combined manuscript figure: A = bars, B = age ----
comb_s2 <- cowplot::plot_grid(p_bars, p_age + ggplot2::labs(title = NULL),
                              ncol = 2, labels = c("A", "B"),
                              rel_widths = c(0.9, 1.15))
ggsave(file.path(fig_dir, "combined_study2.png"), comb_s2,
       width = 11, height = 5.2, dpi = 300, bg = "white")

comb_s2
# AGE ANALYSES (Woo-style) ----
# (a) epistemic x age interaction  -> xfit_age (fitted above, §6.5.1)
# (b) whole-group model (no age)   -> the effect reported in the main text
# (c) categorical-age model        -> per-age-year (5-8) estimated P

xfit_noage <- fit_or_load("s2_noage.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic + (1 | participantId), dat))

dat$age_yr <- factor(floor(dat$age_best))
xfit_ageyr <- fit_or_load("s2_ageyr.rds", function()
  brm_std(choseIndividualAsBF ~ epistemic * age_yr + (1 | participantId), dat))
emm_ageyr <- as.data.frame(
  emmeans::emmeans(xfit_ageyr, specs = c("epistemic", "age_yr"),
                   type = "response"))
readr::write_csv(emm_ageyr, file.path(results_dir, "age_effects.csv"))


# EXPORT TABLES FOR THE MANUSCRIPT ----

model_tbl <- dplyr::bind_rows(
  tidy_post(xfit_main,     "s2_main"),
  tidy_post(xfit_young,    "s2_younger"),
  tidy_post(xfit_old,      "s2_older"),
  tidy_post(xfit_age,      "s2_age_continuous"),
  tidy_post(xfit_age_all,  "s2_age_continuous_4to8"),
  tidy_post(xfit_tight,    "s2_priors_tight"),
  tidy_post(xfit_wide,     "s2_priors_wide"),
  tidy_post(xfit_complete, "s2_complete_only"),
  tidy_post(xfit_6older,   "s2_6_with_older"),
  tidy_post(xfit_noage,    "s2_noage"),
  tidy_post(xfit_rt,       "s2_rt"),
  tidy_post(xfit_item,     "s2_item"),
  tidy_post(xfit_nuis,     "s2_nuisance")
)
readr::write_csv(model_tbl, file.path(results_dir, "model_estimates.csv"))


# MODEL DIAGNOSTICS (supplement) ----

s2_models <- list(
  s2_main = xfit_main, s2_younger = xfit_young, s2_older = xfit_old,
  s2_age_continuous = xfit_age, s2_age_continuous_4to8 = xfit_age_all,
  s2_priors_tight = xfit_tight,
  s2_priors_wide = xfit_wide, s2_complete_only = xfit_complete,
  s2_6_with_older = xfit_6older, s2_noage = xfit_noage,
  s2_rt = xfit_rt, s2_item = xfit_item, s2_nuisance = xfit_nuis
)
model_diag <- function(m, name) {
  dp <- bayestestR::diagnostic_posterior(m, effects = "all", component = "all")
  np <- brms::nuts_params(m)
  data.frame(model = name,
             max_Rhat = round(max(dp$Rhat, na.rm = TRUE), 3),
             min_ESS  = round(min(dp$ESS,  na.rm = TRUE)),
             n_divergent = sum(np$Value[np$Parameter == "divergent__"]))
}
diag_tbl <- dplyr::bind_rows(Map(model_diag, s2_models, names(s2_models)))
readr::write_csv(diag_tbl, file.path(results_dir, "model_diagnostics.csv"))
print(as.data.frame(diag_tbl), row.names = FALSE)

message("analyze_study2_bayes.R complete - models in ", models_dir,
        " ; tables in ", results_dir, " ; figures in ", fig_dir)
