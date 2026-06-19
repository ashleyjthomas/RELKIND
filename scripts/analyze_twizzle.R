# =============================================================
#  Twizzle Town — preliminary data analysis
#  PI: Ashley Thomas, Harvard University
#
#  Inputs:
#    A TSV / CSV / Excel export of the Google Sheet receiving
#    per-trial rows from index.html. Default path is
#    twizzle_data.tsv next to this script.
#
#  Outputs (saved next to this script):
#    figures/   PNG plots
#    tables/    summary CSVs
#
#  Usage:
#    From RStudio: open this file, set Working Directory →
#       "To Source File Location", then Source.
#    From terminal: Rscript scripts/analyze_twizzle.R
# =============================================================

# ---- 0. Setup ------------------------------------------------
suppressPackageStartupMessages({
  needed <- c("tidyverse", "lme4", "broom", "broom.mixed", "scales")
  to_install <- needed[!needed %in% installed.packages()[, "Package"]]
  if (length(to_install)) install.packages(to_install)
  library(tidyverse)
  library(lme4)
  library(broom)
  library(broom.mixed)
  library(scales)
})

options(dplyr.summarise.inform = FALSE)

# Resolve paths relative to this script
this_file <- tryCatch(
  rstudioapi::getSourceEditorContext()$path,
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- sub("--file=", "", args[grep("--file=", args)])
    if (length(file_arg)) file_arg else "analyze_twizzle.R"
  }
)
SCRIPT_DIR <- normalizePath(dirname(this_file), mustWork = FALSE)
setwd(SCRIPT_DIR)

DATA_PATH <- file.path(SCRIPT_DIR, "twizzle_data.tsv")
if (!file.exists(DATA_PATH)) {
  # Fall back to common alternate locations / extensions
  alt <- c("twizzle_data.csv", "data.tsv", "data.csv",
           "../twizzle_data.tsv", "../twizzle_data.csv")
  hit <- alt[file.exists(file.path(SCRIPT_DIR, alt))][1]
  if (!is.na(hit)) DATA_PATH <- file.path(SCRIPT_DIR, hit)
}
stopifnot("Data file not found. Save the Google Sheet as twizzle_data.tsv next to this script." =
            file.exists(DATA_PATH))

dir.create("figures", showWarnings = FALSE)
dir.create("tables",  showWarnings = FALSE)

# ---- 1. Read + clean -----------------------------------------
read_any <- function(p) {
  if (grepl("\\.tsv$|\\.txt$", p, ignore.case = TRUE)) {
    readr::read_tsv(p, show_col_types = FALSE)
  } else if (grepl("\\.csv$", p, ignore.case = TRUE)) {
    readr::read_csv(p, show_col_types = FALSE)
  } else stop("Unknown extension: ", p)
}

raw <- read_any(DATA_PATH)
cat("Loaded", nrow(raw), "rows from", basename(DATA_PATH), "\n\n")

# Standardize the key columns
dat <- raw |>
  mutate(
    participantId         = as.character(participantId),
    firstName             = as.character(firstName),
    age                   = as.numeric(age),
    questionType          = factor(questionType,        levels = c("close", "boss")),
    epistemic             = factor(epistemic,           levels = c("hmm", "yes")),
    effectiveRoleA        = factor(effectiveRoleA,      levels = c("group", "individual")),
    effectiveRoleB        = factor(effectiveRoleB,      levels = c("group", "individual")),
    chosenRole            = factor(chosenRole,          levels = c("group", "individual")),
    hypothesisConsistent  = as.integer(hypothesisConsistent),
    rt_ms                 = as.numeric(rt_ms),
    timestamp             = suppressWarnings(as.POSIXct(timestamp, tz = "UTC"))
  ) |>
  # Drop QA / pilot rows
  filter(
    !is.na(participantId),
    !toupper(participantId) %in% c("TEST", "TESTING"),
    !toupper(firstName)     %in% c("TEST", "TESTING")
  ) |>
  # If a kid retried, keep their first attempt only (deduplicate by participant + stimulus tag)
  arrange(participantId, timestamp) |>
  distinct(participantId, dataExportTag, .keep_all = TRUE)

cat("After cleaning:", nrow(dat), "trials,",
    n_distinct(dat$participantId), "participants\n")

# ---- Age-based exclusion -------------------------------------
# Exclude 4-year-olds (Set MIN_AGE to whatever lower bound you want;
# raise/lower it later without touching anything else.)
MIN_AGE <- 5
n_before <- n_distinct(dat$participantId)
dat <- dat |> filter(age >= MIN_AGE)
n_after  <- n_distinct(dat$participantId)
cat("\nExcluded", n_before - n_after, "participants younger than", MIN_AGE,
    "(now", n_after, "participants,", nrow(dat), "trials)\n")

# Trials per participant (diagnostic — we keep everyone regardless)
trial_counts <- dat |>
  count(participantId, name = "n_trials") |>
  arrange(n_trials)
cat("\nTrial-count distribution (all participants kept):\n")
print(table(trial_counts$n_trials))
cat("Participants who didn't complete all 12 trials:",
    sum(trial_counts$n_trials < 12), "\n")
write_csv(trial_counts, "tables/trial_counts_per_participant.csv")

# Use every valid participant — partial sessions contribute the trials they did finish.
dat_full <- dat
cat("\nParticipants in analysis:", n_distinct(dat_full$participantId), "\n")

# Age distribution
cat("\nAge distribution:\n")
print(table(dat_full |> distinct(participantId, age) |> pull(age)))

# ---- 2. Per-participant means --------------------------------
pp <- dat_full |>
  group_by(participantId, age, questionType, epistemic) |>
  summarise(
    n_trials       = n(),
    p_hypothesis   = mean(hypothesisConsistent, na.rm = TRUE),
    .groups        = "drop"
  )

write_csv(pp, "tables/per_participant_cell_means.csv")

# ---- 3. Cell-level descriptives ------------------------------
cell_summary <- pp |>
  group_by(questionType, epistemic) |>
  summarise(
    n_participants = n(),
    mean_p         = mean(p_hypothesis),
    sd_p           = sd(p_hypothesis),
    se_p           = sd_p / sqrt(n_participants),
    ci_lo          = mean_p - 1.96 * se_p,
    ci_hi          = mean_p + 1.96 * se_p,
    .groups        = "drop"
  )
cat("\nCell means (proportion of hypothesis-consistent choices, per participant):\n")
print(cell_summary)
write_csv(cell_summary, "tables/cell_means.csv")

# Aggregated by questionType only
qtype_summary <- pp |>
  group_by(questionType) |>
  summarise(
    n_participants = n_distinct(participantId),
    mean_p         = mean(p_hypothesis),
    sd_p           = sd(p_hypothesis),
    .groups        = "drop"
  )
cat("\nBy questionType:\n"); print(qtype_summary)

# ---- 4. One-sample tests vs chance (50%) ---------------------
# Per cell: are children above chance? (per-participant proportions vs 0.5)
chance_tests <- pp |>
  group_by(questionType, epistemic) |>
  summarise(
    n           = n(),
    mean_p      = mean(p_hypothesis),
    t_stat      = if (n() > 1) t.test(p_hypothesis, mu = 0.5)$statistic else NA,
    df          = if (n() > 1) t.test(p_hypothesis, mu = 0.5)$parameter else NA,
    p_value     = if (n() > 1) t.test(p_hypothesis, mu = 0.5)$p.value   else NA,
    .groups     = "drop"
  )
cat("\nOne-sample t-tests vs chance (0.5):\n"); print(chance_tests)
write_csv(chance_tests, "tables/chance_tests_per_cell.csv")

# Trial-level binomial test as a sanity check (ignores participant clustering)
cat("\nTrial-level binomial tests vs chance (no clustering):\n")
binom_tests <- dat_full |>
  group_by(questionType, epistemic) |>
  summarise(
    n_trials = n(),
    n_hyp    = sum(hypothesisConsistent == 1),
    p        = n_hyp / n_trials,
    p_value  = binom.test(n_hyp, n_trials, p = 0.5)$p.value,
    .groups  = "drop"
  )
print(binom_tests)
write_csv(binom_tests, "tables/binomial_tests_per_cell.csv")

# ---- 5. Mixed-effects logistic regression --------------------
# Sum-coded contrasts so the intercept = grand mean log-odds
dat_full <- dat_full |>
  mutate(
    qtype_c     = factor(questionType, levels = c("close", "boss")),
    epist_c     = factor(epistemic,    levels = c("hmm",   "yes")),
    age_c       = scale(age, center = TRUE, scale = FALSE) |> as.numeric()
  )
contrasts(dat_full$qtype_c) <- contr.sum(2); colnames(contrasts(dat_full$qtype_c)) <- "boss_vs_close"
contrasts(dat_full$epist_c) <- contr.sum(2); colnames(contrasts(dat_full$epist_c)) <- "yes_vs_hmm"

cat("\nFitting mixed-effects logistic regression:\n",
    "  hypothesisConsistent ~ questionType * epistemic + age_c + (1 | participantId)\n")
m1 <- tryCatch(
  glmer(
    hypothesisConsistent ~ qtype_c * epist_c + age_c + (1 | participantId),
    data    = dat_full,
    family  = binomial,
    control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
  ),
  error = function(e) { warning(conditionMessage(e)); NULL }
)
if (!is.null(m1)) {
  print(summary(m1))
  tidy_m1 <- broom.mixed::tidy(m1, conf.int = TRUE, exponentiate = FALSE)
  print(tidy_m1)
  write_csv(tidy_m1, "tables/glmer_main.csv")
} else {
  cat("Main model failed to converge — falling back to fixed-effects logistic regression.\n")
  m1 <- glm(
    hypothesisConsistent ~ qtype_c * epist_c + age_c,
    data = dat_full, family = binomial
  )
  print(summary(m1))
  tidy_m1 <- broom::tidy(m1, conf.int = TRUE)
  write_csv(tidy_m1, "tables/glm_main.csv")
}

# ---- 6. Plots ------------------------------------------------
theme_set(theme_minimal(base_size = 12) +
            theme(strip.background = element_blank(),
                  panel.grid.minor = element_blank()))

# 6a. Cell means with 95% CIs over per-participant proportions
p_cells <- ggplot(cell_summary,
                  aes(x = epistemic, y = mean_p, fill = questionType)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey60") +
  geom_col(position = position_dodge(width = 0.7), width = 0.6, alpha = 0.85) +
  geom_errorbar(aes(ymin = pmax(0, ci_lo), ymax = pmin(1, ci_hi)),
                width = 0.18, position = position_dodge(width = 0.7)) +
  geom_text(aes(label = sprintf("n=%d", n_participants),
                y = pmin(1, ci_hi) + 0.04),
            position = position_dodge(width = 0.7), size = 3.2, color = "grey30") +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, 1.05), breaks = seq(0, 1, 0.25)) +
  scale_fill_manual(values = c(close = "#3498db", boss = "#e67e22")) +
  labs(
    title    = "Proportion of hypothesis-consistent choices",
    subtitle = "Per-participant means; bars = 95% CI; dashed line = chance",
    x        = "Epistemic certainty of speakers",
    y        = "Hypothesis-consistent (%)",
    fill     = "Question"
  )
ggsave("figures/01_cell_means.png", p_cells, width = 7, height = 4.5, dpi = 200)

# 6b. Per-participant dots overlaid on cell means
p_dots <- ggplot(pp,
                 aes(x = interaction(questionType, epistemic, sep = " · "),
                     y = p_hypothesis, color = questionType)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey60") +
  geom_jitter(width = 0.15, height = 0.02, size = 2, alpha = 0.55) +
  stat_summary(fun = mean, geom = "crossbar", width = 0.4,
               color = "black", linewidth = 0.4) +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
  scale_color_manual(values = c(close = "#3498db", boss = "#e67e22"), guide = "none") +
  labs(
    title    = "Each child's proportion of hypothesis-consistent choices",
    subtitle = "Black bar = group mean; dashed line = chance",
    x        = NULL, y = "Hypothesis-consistent (%)"
  )
ggsave("figures/02_participant_dots.png", p_dots, width = 8, height = 4.5, dpi = 200)

# 6c. Effect of age
age_summary <- pp |>
  group_by(age, questionType) |>
  summarise(mean_p = mean(p_hypothesis),
            n      = n(),
            se     = sd(p_hypothesis) / sqrt(n),
            .groups = "drop")

p_age <- ggplot(age_summary, aes(x = age, y = mean_p, color = questionType)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey60") +
  geom_point(aes(size = n)) +
  geom_line(linewidth = 0.6) +
  geom_errorbar(aes(ymin = mean_p - se, ymax = mean_p + se), width = 0.15) +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
  scale_x_continuous(breaks = 4:8) +
  scale_color_manual(values = c(close = "#3498db", boss = "#e67e22")) +
  scale_size_continuous(name = "n children", range = c(2, 6)) +
  labs(
    title = "Hypothesis-consistent responding by age",
    x = "Age (years)", y = "Hypothesis-consistent (%)", color = "Question"
  )
ggsave("figures/03_by_age.png", p_age, width = 7, height = 4.5, dpi = 200)

# 6d. RT diagnostic (helps spot kids who weren't really attending)
p_rt <- dat_full |>
  filter(rt_ms < 60000) |>  # drop extreme outliers (>1 min) for the plot
  ggplot(aes(x = rt_ms / 1000)) +
  geom_histogram(bins = 40, fill = "#7d8a8a", alpha = 0.8) +
  facet_wrap(~ questionType) +
  labs(title = "Response-time distribution by question type",
       x = "Response time (seconds)", y = "Trial count")
ggsave("figures/04_rt_distribution.png", p_rt, width = 7, height = 4, dpi = 200)

cat("\nAll done.\n")
cat("Figures saved to:", file.path(SCRIPT_DIR, "figures"), "\n")
cat("Tables  saved to:", file.path(SCRIPT_DIR, "tables"),  "\n")
