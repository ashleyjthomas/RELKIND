# ============================================================================
#  TWIZZLE_CLEAN.R - main analysis script for Twizzle Town
#  "Children's inferences about relationships from the way people explain
#   behavior" 
#
#  This script:
#    - loads the CHS-merged trial-level export ("twizzle_data_with_age.csv")
#    - filters to the pre-registered analytic sample
#    - fits Bayesian hierarchical logistic (probit-mixed) models to disk
#      (cached in "5. Analysis/results/models/*.rds")
#    - produces the forced-choice bar plots and developmental (age) plots
#
#  All paths use here::here() so the script runs from the project root
#  (open TWIZZLE.Rproj in RStudio).
#
#  DV CODING (everywhere): chose_individual = 1 if the participant chose the
#  INDIVIDUAL-referring speaker; 0 if the GROUP-referring speaker.
#
#  DESIGN
#    2 (questionType: close = "who is X's best friend" / boss = "who is X's boss?") x
#    2 (epistemic  : yes = based on existing knowledge / hmm = not existing knowledge)
#    within-subjects (each child does one epistemic level per block)
#
#  PRE-REGISTERED HYPOTHESES
#    H1 (close block, both epistemic cells): P(individual) > .5
#    H2 (boss  block, both epistemic cells): P(individual) < .5     [dropped]
#    H3 (age)  : responding is stronger in Older (7-8) than Younger (5-6)
#    H4 (epistemic, exploratory): epistemic frame moderates H1 / H2
#
#  ANALYTIC SAMPLE
#    Post-best-friend cutoff (2026-06-20 02:30 UTC), ages 5-8 = pre-registered
#    sample. 4-year-olds and pilot sessions reported as exploratory.
#
#  Companion: TWIZZLE_manuscript.qmd renders the paper from the .rds files
#  this script produces.
# ============================================================================

library(here)   # for project-relative paths


# SETUP ----

## Packages ----

ipak <- function(pkg) {
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

packages <- c(
  "afex", "vcd", "ggplot2", "likert", "lattice", "pbkrtest",
  "reshape2", "car", "plyr", "MASS", "lme4", "effects",
  "lmerTest", "multcomp", "lsmeans", "Hmisc", "tidyr",
  "ordinal", "brms", "jtools", "DHARMa", "rstanarm",
  "BayesFactor", "bayesplot", "tidybayes", "magrittr",
  "ggeffects", "sjmisc", "splines", "tidyverse", "bayestestR",
  "HDInterval", "dplyr", "formattable", "gt", "tufte", "tinytex",
  "performance", "stringr", "cowplot", "emmeans", "sjPlot"
)
ipak(packages)

library(dplyr)  # load after plyr to avoid masking


## Paths ----
# RELKIND repo layout: scripts/ holds this file, the CSVs, and the output
# subdirectories (fits/, tables/, figures/). here::here() resolves relative
# to the .git / .Rproj root, so all four paths sit under scripts/.

raw_dir     <- here::here("scripts")
models_dir  <- here::here("scripts", "fits")
results_dir <- here::here("scripts", "tables")
fig_dir     <- here::here("scripts", "figures")
dir.create(models_dir,  recursive = TRUE, showWarnings = FALSE)
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir,     recursive = TRUE, showWarnings = FALSE)


## Shared palette ----

okabe_ito <- c(
  "#000000", "#E69F00", "#56B4E9",
  "#009E73", "#F0E442", "#0072B2",
  "#D55E00", "#CC79A7"
)

# fill scheme for the forced-choice bars (individual coloured by condition; group grey)
twizzle_fills <- c(
  "Group"             = "grey80",
  "Individual (yes)"  = "#0072B2",
  "Individual (hmm)"  = "#E88A8A"
)

# epistemic colours for the age (line) plots  (yes = blue apparently known, hmm = pink apparently learning)
cond_cols <- c(Yes = "#0072B2", Hmm = "#E88A8A")

# pretty labels for questionType / epistemic facets
pretty_qt  <- c(close = "Close (best friend)", boss = "Boss")
pretty_ep  <- c(yes   = "Yes (apparently known)",     hmm  = "Hmm (apparently learning)")


## Shared priors ----
# Weakly-informative on the probit scale, matching pre-reg §6.1.

priors_A <- c(
  prior(normal(0, 2.5), class = "b"),
  prior(normal(0, 5),   class = "Intercept"),
  prior(exponential(1), class = "sd")
)
priors_B <- c(
  prior(normal(0, 1),     class = "b"),
  prior(normal(0, 3),     class = "Intercept"),
  prior(exponential(1.5), class = "sd")
)
priors_C <- c(
  prior(normal(0, 5),     class = "b"),
  prior(normal(0, 10),    class = "Intercept"),
  prior(exponential(0.5), class = "sd")
)


## Shared helper functions ----

# fit a brms model the first time, then load it from disk on later runs
fit_or_load <- function(file, fit_fun) {
  path <- file.path(models_dir, file)
  if (file.exists(path)) return(readRDS(path))
  m <- fit_fun()
  saveRDS(m, path)
  m
}

# standard brms call used throughout: PROBIT mixed model, default priors
# (matches pre-reg §6.1: "Bayesian probit generalized linear mixed model")
brm_std <- function(formula, data, adapt_delta = 0.8) {
  brm(formula, data = data, family = bernoulli(link = "probit"),
      save_pars = save_pars(all = TRUE),
      iter = 4000, warmup = 1000, thin = 1, chains = 4,
      cores = 4, seed = 123, refresh = 0,
      control = list(adapt_delta = adapt_delta))
}

# ONE-SIDED Bayesian binomial test vs chance (JZS prior).
# For the pre-registered "close" hypothesis:  direction = "individual" (p > .5).
# For the pre-registered "boss"  hypothesis:  direction = "group"      (p < .5).
# Returns BF10 for that directional alternative vs the point null at .5.
bf_chance <- function(k, n, direction = "individual") {
  interval <- if (direction == "individual") c(0.5, 1) else c(0, 0.5)
  bf <- BayesFactor::proportionBF(k, n, p = 0.5, nullInterval = interval)
  as.numeric(as.vector(bf))[1]
}

# per-cell summary: % chose individual + one-sided BF vs chance
cell_summary <- function(dat, direction = "individual") {
  grp <- intersect(c("population", "age_group", "questionType", "epistemic"),
                   names(dat))
  dat %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(grp))) %>%
    dplyr::summarise(
      n       = sum(!is.na(chose_individual)),
      k_ind   = sum(chose_individual, na.rm = TRUE),
      pct_ind = round(100 * k_ind / n),
      BF10    = round(bf_chance(k_ind, n, direction), 2),
      BF01    = round(1 / BF10, 2),
      .groups = "drop"
    ) %>%
    dplyr::mutate(direction = direction)
}

# shared ggplot theme
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

# significance stars from a one-sided BF (vs chance, in the hypothesis direction)
bf_star <- function(bf) dplyr::case_when(bf >= 100 ~ "***", bf >= 10 ~ "**",
                                          bf >= 3   ~ "*",  TRUE     ~ "")

# posterior median / 95% CI / % in ROPE / pd for one model
tidy_post <- function(model, name) {
  dp <- describe_posterior(model, ci = .95, rope_range = c(-0.1, 0.1),
                           rope_ci = 1, test = c("rope", "pd"))
  as.data.frame(dp) %>%
    transmute(model = name, term = Parameter,
              median = round(Median, 2), CI_low = round(CI_low, 2),
              CI_high = round(CI_high, 2),
              pct_in_ROPE = round(100 * ROPE_Percentage, 1), pd = round(pd, 3))
}

# mean age of the child sample (for back-transforming centred age on the x axis)
mean_age <- function(d) mean(d$age_years[d$population == "child"], na.rm = TRUE)


## Forced-choice bar plot ----
# Stacked %-individual vs %-group by (facet variable) x (epistemic condition).
# Chance line dashed at .5; significance stars above each bar (one-sided BF vs
# chance in `direction`). No plot title; caption identifies the panels.

plot_twizzle_bars <- function(dat, x_var = "questionType",
                              direction = "individual",
                              y_name    = "% of answers") {

  cell <- dat %>%
    dplyr::filter(!is.na(chose_individual)) %>%
    dplyr::group_by(.data[[x_var]], epistemic) %>%
    dplyr::summarise(ind = mean(chose_individual), n = dplyr::n(),
                     k = sum(chose_individual), .groups = "drop") %>%
    dplyr::rowwise() %>%
    dplyr::mutate(star = bf_star(bf_chance(k, n, direction))) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      epistemic = factor(stringr::str_to_title(as.character(epistemic)),
                         levels = c("Yes", "Hmm")),
      facet     = factor(pretty_qt[as.character(.data[[x_var]])],
                         levels = unname(pretty_qt))
    )

  bars <- cell %>%
    dplyr::mutate(group = 1 - ind) %>%
    tidyr::pivot_longer(c(ind, group), names_to = "choice", values_to = "prop") %>%
    dplyr::mutate(fill_group = factor(dplyr::case_when(
      choice == "group"   ~ "Group",
      epistemic == "Yes"  ~ "Individual (yes)",
      TRUE                ~ "Individual (hmm)"),
      levels = c("Group", "Individual (yes)", "Individual (hmm)")))

  ggplot(bars, aes(epistemic, prop, fill = fill_group)) +
    geom_col(width = 0.8, colour = "black", linewidth = 1.1) +
    geom_hline(yintercept = 0.5, linetype = "dashed", colour = "black",
               linewidth = 0.6) +
    geom_text(data = cell, aes(epistemic, 1.02, label = star),
              inherit.aes = FALSE, vjust = 0, size = 6, fontface = "bold") +
    facet_wrap(~ facet, nrow = 1) +
    scale_fill_manual(values = twizzle_fills, name = NULL) +
    scale_y_continuous(breaks = c(0, .25, .5, .75, 1),
                       labels = c("0", "25", "50", "75", "100"),
                       expand = expansion(mult = c(0, 0.09))) +
    coord_cartesian(clip = "off") +
    labs(x = NULL, y = y_name) +
    theme_study()
}


## Developmental (age) plot ----
# Model-predicted P(individual) over age from a brms fit
# (conditional_effects ribbon + line), individual jittered responses,
# and a dashed CHANCE reference line at .5.  Children only.
#
# `group_var` (optional) is a factor whose levels are faceted (e.g., "questionType"),
# with the fit's conditional_effects looped over those levels so each panel gets
# its own posterior curves rather than being averaged.

plot_twizzle_age <- function(fit, dat_child,
                             group_var = NULL, m_age, title = NULL) {

  prep_ep <- function(d) dplyr::mutate(d,
    epistemic = factor(stringr::str_to_title(as.character(epistemic)),
                       levels = c("Yes", "Hmm")))

  # predicted curves (loop conditions over the grouping factor)
  ce_for <- function(cond = NULL)
    as.data.frame(conditional_effects(fit, effects = "age_c:epistemic",
                                      conditions = cond)[[1]])
  if (is.null(group_var)) {
    ce <- ce_for()
  } else {
    glevels <- levels(factor(dat_child[[group_var]]))
    ce <- dplyr::bind_rows(lapply(glevels, function(g) {
      cond <- stats::setNames(
        data.frame(factor(g, levels = glevels)), group_var)
      d <- ce_for(cond)
      d[[group_var]] <- g
      d
    }))
  }
  ce  <- prep_ep(ce) %>% dplyr::mutate(age_years = age_c + m_age)
  raw <- prep_ep(dplyr::filter(dat_child, !is.na(chose_individual)))

  if (!is.null(group_var)) {
    relab <- function(x) factor(pretty_qt[as.character(x)],
                                levels = unname(pretty_qt))
    ce$facet  <- relab(ce[[group_var]])
    raw$facet <- relab(raw[[group_var]])
  }

  p <- ggplot(ce, aes(age_years, estimate__, colour = epistemic, fill = epistemic)) +
    geom_hline(aes(yintercept = 0.5, linetype = "Chance (.5)"),
               colour = "black", linewidth = 0.6) +
    geom_jitter(data = raw, inherit.aes = FALSE,
                aes(age_years, chose_individual, colour = epistemic),
                width = 0.05, height = 0.03, alpha = 0.3, size = 1.5) +
    geom_ribbon(aes(ymin = lower__, ymax = upper__), alpha = 0.2, colour = NA) +
    geom_line(aes(linetype = "Children (model)"), linewidth = 1) +
    scale_colour_manual(values = cond_cols, name = "Epistemic",
                        aesthetics = c("colour", "fill")) +
    scale_linetype_manual(name = NULL,
                          values = c("Children (model)" = "solid",
                                     "Chance (.5)"      = "dashed"),
                          guide = guide_legend(override.aes = list(colour = "black",
                                                                   fill = NA))) +
    scale_y_continuous(labels = scales::percent, breaks = c(0, .5, 1)) +
    scale_x_continuous(breaks = 4:9) +
    coord_cartesian(ylim = c(0, 1)) +
    labs(title = stringr::str_wrap(title, 40),
         x = "Age (years)", y = "P(choose individual)") +
    theme_study() +
    theme(panel.grid.major.y = element_line(colour = "grey90"),
          plot.title = element_text(size = 14, face = "bold", hjust = 0,
                                    margin = margin(b = 8)),
          plot.title.position = "plot",
          legend.position = "bottom",
          legend.box = "vertical",
          legend.box.just = "center",
          legend.spacing.y = unit(1, "pt"),
          legend.margin = margin(2, 4, 2, 4),
          legend.key.width = unit(1.4, "cm"),
          plot.margin = margin(t = 10, r = 12, b = 6, l = 8))
  if (!is.null(group_var)) p <- p + facet_wrap(~ facet)
  p
}


# DATA ----

## Load raw source ----
# Preferred input: twizzle_data_with_age.csv (game data merged with the CHS
# 'child__age_in_days' column). Falls back to the Google-Sheet export.

data_file <- if (file.exists(here::here(raw_dir, "twizzle_data_with_age.csv"))) {
  here::here(raw_dir, "twizzle_data_with_age.csv")
} else if (file.exists(here::here(raw_dir, "GAME_RELKIND - Data (14).csv"))) {
  here::here(raw_dir, "GAME_RELKIND - Data (14).csv")
} else {
  stop("Data file not found; put twizzle_data_with_age.csv (or the Sheet export) in ", raw_dir)
}
raw <- read.csv(data_file, stringsAsFactors = FALSE)
message("Loaded ", nrow(raw), " rows from ", basename(data_file))

# Ensure the CHS-derived age columns are present even if we loaded the Sheet
if (!"age_in_days_chs" %in% names(raw)) raw$age_in_days_chs <- NA_real_
if (!"age_years_chs"   %in% names(raw)) raw$age_years_chs   <- NA_real_


## Clean, dedup, and code ----

dat <- raw %>%
  dplyr::mutate(
    ID              = as.character(participantId),
    firstName       = as.character(firstName),
    age             = suppressWarnings(as.numeric(age)),                 # caregiver-reported year
    age_in_days_chs = suppressWarnings(as.numeric(age_in_days_chs)),
    age_years_chs   = suppressWarnings(as.numeric(age_years_chs)),
    # Continuous age: prefer CHS days, otherwise caregiver year + 0.5
    age_years       = dplyr::coalesce(age_years_chs, age + 0.5),
    ts              = suppressWarnings(as.POSIXct(timestamp,
                                                  format = "%Y-%m-%dT%H:%M:%OS",
                                                  tz = "UTC")),
    questionType    = factor(questionType, levels = c("close", "boss")),
    epistemic       = factor(epistemic,    levels = c("yes",   "hmm")),
    chosenRole      = factor(chosenRole,   levels = c("group", "individual")),
    chose_individual = as.integer(chosenRole == "individual"),
    population      = "child",
    rt_ms           = suppressWarnings(as.numeric(rt_ms))
  ) %>%
  dplyr::filter(
    !is.na(ID), !ID %in% c("TEST", "TESTING", "PILOT"),
    !toupper(firstName) %in% c("TEST", "TESTING", "PILOT", ""),
    !is.na(chose_individual)
  ) %>%
  # first attempt only: dedup by (participant + stimulus tag)
  dplyr::arrange(ID, ts) %>%
  dplyr::distinct(ID, dataExportTag, .keep_all = TRUE)


## Post-pilot cutoff (best-friend audio deployment) ----
# Sessions before this heard the pilot "closer" wording. Post-cutoff = the
# pre-registered wording ("best friend"). Exclude pilot from the confirmatory
# sample; keep them for exploratory sensitivity.

CUTOFF <- as.POSIXct("2026-06-20 02:30:00", tz = "UTC")
dat <- dat %>%
  dplyr::group_by(ID) %>%
  dplyr::mutate(ts_start = min(ts, na.rm = TRUE)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(is_post_pilot = ts_start >= CUTOFF)


## Age-group factor (pre-reg §6.2) ----
# 4yo reported separately as exploratory; Younger (5-6) vs Older (7-8) is the
# pre-registered contrast.

dat <- dat %>%
  dplyr::mutate(age_group = factor(dplyr::case_when(
      age_years <  5 ~ "4yo (exploratory)",
      age_years <  7 ~ "Younger (5-6)",
      age_years <  9 ~ "Older (7-8)",
      TRUE           ~ "9+"),
    levels = c("4yo (exploratory)", "Younger (5-6)", "Older (7-8)", "9+")))


## Centred continuous age (within child sample) ----

add_age_c <- function(d) {
  d$age_c <- d$age_years - mean(d$age_years[d$population == "child"],
                                na.rm = TRUE)
  d
}
dat <- add_age_c(dat)


## Analytic samples ----

# Pre-registered confirmatory: post-cutoff wording, ages 5.0-8.99
twizzle_reg <- dat %>%
  dplyr::filter(is_post_pilot, age_years >= 5, age_years < 9)

# Exploratory including 4-year-olds
twizzle_all <- dat %>%
  dplyr::filter(is_post_pilot, age_years >= 4, age_years < 9)

# Both centred within each sample
twizzle_reg <- add_age_c(twizzle_reg)
twizzle_all <- add_age_c(twizzle_all)

message("Pre-registered sample (post-pilot, 5-8): ",
        dplyr::n_distinct(twizzle_reg$ID), " kids ; ", nrow(twizzle_reg), " trials")
message("Exploratory sample   (post-pilot, 4-8): ",
        dplyr::n_distinct(twizzle_all$ID), " kids ; ", nrow(twizzle_all), " trials")


# STUDY: Twizzle Town (pre-registered) ----

## Cell means + one-sided BFs vs chance ----
# Pre-reg directions:
#   close (H1) -> individual  (p > .5)
#   boss  (H2) -> group       (p < .5)   [dropped as directional hypothesis]

twiz_close <- dplyr::filter(twizzle_reg, questionType == "close")
twiz_boss  <- dplyr::filter(twizzle_reg, questionType == "boss")

close_bf   <- cell_summary(twiz_close, direction = "individual") %>%
                dplyr::mutate(questionType = "close")
boss_bf_g  <- cell_summary(twiz_boss,  direction = "group")      %>%
                dplyr::mutate(questionType = "boss (direction = group)")
boss_bf_i  <- cell_summary(twiz_boss,  direction = "individual") %>%
                dplyr::mutate(questionType = "boss (direction = individual)")

cell_bf_tbl <- dplyr::bind_rows(close_bf, boss_bf_g, boss_bf_i) %>%
  dplyr::relocate(questionType)
readr::write_csv(cell_bf_tbl, file.path(results_dir, "cell_BF.csv"))
print(cell_bf_tbl)


## Primary GLMM (pre-reg §6.1): condition x age_group x epistemic ----
# Probit mixed model with random intercepts by participant.

xfit_twiz_main <- fit_or_load("twizzle_main.rds", function()
  brm_std(chose_individual ~ questionType * epistemic * age_group + (1 | ID),
          twizzle_reg))
print(xfit_twiz_main)


## Continuous-age model (pre-reg §6.5 sensitivity) ----
# Same design as §6.1 but with continuous centred age instead of age_group.
# This is the model that feeds plot_twizzle_age().

xfit_twiz_age <- fit_or_load("twizzle_age.rds", function()
  brm_std(chose_individual ~ questionType * epistemic * age_c + (1 | ID),
          twizzle_reg))

# Whole-group model (no age at all) -> reported alongside the age model as the
# main-effect estimate ignoring age.
xfit_twiz_noage <- fit_or_load("twizzle_noage.rds", function()
  brm_std(chose_individual ~ questionType * epistemic + (1 | ID), twizzle_reg))


## Bar plot ----

p_bars <- plot_twizzle_bars(twizzle_reg, x_var = "questionType",
                            direction = "individual")
ggsave(file.path(fig_dir, "twizzle_bars.png"), p_bars,
       width = 8.5, height = 5.5, dpi = 300, bg = "white")


## Age figures (from the continuous-age child model) ----

m_age_reg <- mean_age(twizzle_reg)

p_age_reg <- plot_twizzle_age(
  xfit_twiz_age, twizzle_reg,
  group_var = "questionType", m_age = m_age_reg,
  title = "Twizzle Town: P(individual) by age (5-8 pre-registered sample)")
p_age_reg

ggsave(file.path(fig_dir, "twizzle_age_reg.png"), p_age_reg,
       width = 9, height = 5.2, dpi = 300, bg = "white")


# EXPLORATORY: 4-year-olds included ----
# Same model + figure on the 4-8 sample (4yo reported separately per pre-reg).

xfit_twiz_age_all <- fit_or_load("twizzle_age_all.rds", function()
  brm_std(chose_individual ~ questionType * epistemic * age_c + (1 | ID),
          twizzle_all))

m_age_all <- mean_age(twizzle_all)
p_age_all <- plot_twizzle_age(
  xfit_twiz_age_all, twizzle_all,
  group_var = "questionType", m_age = m_age_all,
  title = "Twizzle Town: P(individual) by age (exploratory, 4-8)")

p_age_all
ggsave(file.path(fig_dir, "twizzle_age_all.png"), p_age_all,
       width = 9, height = 5.2, dpi = 300, bg = "white")


# AGE ANALYSES (Woo-style) ----
# For the confirmatory sample:
#   (a) condition x age_c interaction   -> from xfit_twiz_age (above)
#   (b) whole-group effect (no age)     -> from xfit_twiz_noage (above)
#   (c) per-age (5, 6, 7, 8) estimates  -> categorical-age model, emmeans

xfit_twiz_ageyr <- fit_or_load("twizzle_ageyr.rds", function() {
  d <- twizzle_reg %>% dplyr::mutate(age_yr = factor(floor(age_years)))
  brm_std(chose_individual ~ questionType * epistemic * age_yr + (1 | ID), d)
})

emm_ageyr <- emmeans::emmeans(xfit_twiz_ageyr,
                              specs = c("questionType", "epistemic", "age_yr"),
                              type  = "response")
age_effects <- as.data.frame(emm_ageyr) %>%
  dplyr::mutate(study = "twizzle") %>% dplyr::relocate(study)
readr::write_csv(age_effects, file.path(results_dir, "age_effects.csv"))


# EXPORT TABLES FOR THE MANUSCRIPT ----

model_tbl <- dplyr::bind_rows(
  tidy_post(xfit_twiz_main,  "twizzle_main"),
  tidy_post(xfit_twiz_age,   "twizzle_age"),
  tidy_post(xfit_twiz_noage, "twizzle_noage"),
  tidy_post(xfit_twiz_ageyr, "twizzle_ageyr"),
  tidy_post(xfit_twiz_age_all, "twizzle_age_all_exploratory")
)
readr::write_csv(model_tbl, file.path(results_dir, "model_estimates.csv"))


# SENSITIVITY ANALYSIS (optional; priors A / B / C) ----
# Mirrors OMIT sensitivity block: fit the primary model under three prior
# specifications and export a combined posterior table.

run_sensitivity <- function(formula, data, tag) {
  list(
    A = fit_or_load(paste0("twizzle_sens_", tag, "_A.rds"), function()
      brm(formula, data = data, family = bernoulli(link = "probit"),
          prior = priors_A, iter = 3000, warmup = 1000, chains = 4,
          cores = 4, seed = 123, refresh = 0)),
    B = fit_or_load(paste0("twizzle_sens_", tag, "_B.rds"), function()
      brm(formula, data = data, family = bernoulli(link = "probit"),
          prior = priors_B, iter = 3000, warmup = 1000, chains = 4,
          cores = 4, seed = 123, refresh = 0)),
    C = fit_or_load(paste0("twizzle_sens_", tag, "_C.rds"), function()
      brm(formula, data = data, family = bernoulli(link = "probit"),
          prior = priors_C, iter = 3000, warmup = 1000, chains = 4,
          cores = 4, seed = 123, refresh = 0))
  )
}
# sens_twiz <- run_sensitivity(
#   chose_individual ~ questionType * epistemic * age_c + (1 | ID),
#   twizzle_reg, "age")
# lapply(sens_twiz, function(m) describe_posterior(m, rope_range = c(-0.1, 0.1)))


# SUPPLEMENT: MODEL DIAGNOSTICS ----

diag_dir <- file.path(fig_dir, "diagnostics")
dir.create(diag_dir, recursive = TRUE, showWarnings = FALSE)

twizzle_models <- list(
  twizzle_main      = xfit_twiz_main,
  twizzle_age       = xfit_twiz_age,
  twizzle_noage     = xfit_twiz_noage,
  twizzle_ageyr     = xfit_twiz_ageyr,
  twizzle_age_all   = xfit_twiz_age_all
)

## Convergence + fit table ----

model_diag <- function(m, name) {
  dp  <- bayestestR::diagnostic_posterior(m, effects = "all", component = "all")
  r2  <- brms::bayes_R2(m)
  np  <- brms::nuts_params(m)
  data.frame(
    model        = name,
    n_param      = nrow(dp),
    max_Rhat     = round(max(dp$Rhat, na.rm = TRUE), 3),
    min_ESS      = round(min(dp$ESS,  na.rm = TRUE)),
    n_divergent  = sum(np$Value[np$Parameter == "divergent__"]),
    BayesR2      = round(r2[, "Estimate"], 3),
    BayesR2_low  = round(r2[, "Q2.5"], 3),
    BayesR2_high = round(r2[, "Q97.5"], 3)
  )
}
diag_tbl <- dplyr::bind_rows(Map(model_diag, twizzle_models, names(twizzle_models)))
readr::write_csv(diag_tbl, file.path(results_dir, "model_diagnostics.csv"))
print(as.data.frame(diag_tbl), row.names = FALSE)


## Posterior predictive checks ----
# Single grid image (pp_all.png). Bars = observed; points/intervals = predicted.

mod_lab_diag <- c(
  twizzle_main    = "Primary GLMM (condition x age_group)",
  twizzle_age     = "Continuous-age GLMM (condition x age_c)",
  twizzle_noage   = "Whole-group GLMM (no age)",
  twizzle_ageyr   = "Categorical-age GLMM (condition x age_yr)",
  twizzle_age_all = "Continuous-age GLMM incl. 4yo (exploratory)"
)
pp_list <- lapply(names(twizzle_models), function(nm) {
  brms::pp_check(twizzle_models[[nm]], type = "dens_overlay", ndraws = 100) +
    ggplot2::labs(title = unname(mod_lab_diag[nm]), x = NULL, y = NULL) +
    theme_study() +
    theme(plot.title      = element_text(size = 8.5, face = "bold"),
          legend.position = "none",
          axis.text       = element_text(size = 7),
          plot.margin     = margin(2, 4, 2, 4))
})
pp_grid <- cowplot::plot_grid(plotlist = pp_list, ncol = 2)
ggsave(file.path(diag_dir, "pp_all.png"), pp_grid,
       width = 9, height = 8, dpi = 150, bg = "white")


# COMBINED MANUSCRIPT FIGURES ----
# One figure per section, built from the in-memory ggplot objects so the age
# panels can share a single legend rather than repeating it.

.figP     <- function(f) file.path(fig_dir, f)
.notitle  <- function(p) p + ggplot2::labs(title = NULL)
.nolegend <- function(p) p + ggplot2::theme(legend.position = "none")

# Main figure: A = bars, B = age (pre-registered sample)
leg_age <- cowplot::get_legend(p_age_reg)
main_ab <- cowplot::plot_grid(
  p_bars,
  .nolegend(.notitle(p_age_reg)),
  ncol = 2, labels = c("A", "B"), rel_widths = c(0.95, 1.15))
main_all <- cowplot::plot_grid(main_ab, leg_age, ncol = 1,
                               rel_heights = c(1, 0.10))
ggsave(.figP("combined_main.png"), main_all,
       width = 12, height = 5.6, dpi = 300, bg = "white")


message("TWIZZLE_CLEAN.R complete -- models in ", models_dir,
        " ; summary tables in ", results_dir,
        " ; figures in ", fig_dir)
