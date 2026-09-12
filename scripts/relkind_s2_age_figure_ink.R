# ============================================================================
#  relkind_s2_age_figure_ink.R
#  RELKIND Study 2: developmental (age) figure in the INK house style
#  (binomial geom_smooth + jittered raw responses, deepskyblue, white panel,
#   thin grey axis lines, dashed chance line
#   lower bound of the pre-registered window — 4-year-olds are exploratory)
#
#  DV: choseIndividualAsBF = 1 if the individual-level explainer was assigned
#  to the best-friend role. INPUT: study2_data.csv (with age_exact column).
# ============================================================================

library(tidyverse)
library(lubridate)

SCRIPT_DIR <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    fa <- sub("--file=", "", args[grep("--file=", args)])
    if (length(fa)) dirname(normalizePath(fa)) else "."
  }
)
setwd(SCRIPT_DIR)
dir.create("figures_ink", showWarnings = FALSE)

raw <- read_csv("study2_data.csv", show_col_types = FALSE)
if (!"choseIndividualAsBF" %in% names(raw)) raw$choseIndividualAsBF <- NA
if (!"age_exact" %in% names(raw)) raw$age_exact <- NA_real_

dat <- raw %>%
  filter(study == "study2",
         !grepl("test", participantId, ignore.case = TRUE),
         !grepl("test", firstName,     ignore.case = TRUE),
         !participantId %in% c("TT009_1785285837662",  # pilot
                       "TT030_1786981806095",
                       "TT048_1786897799066",
                       "TT072_1786982010792",
                       "TT007_1787400154701",
                       "TT086_1787401130147",
                       "TT047_1788009524301",
                       "TT035_1788184474250",
                       "TT026_1788255831256")) %>%  # arlo: no consent record
  mutate(ts = ymd_hms(timestamp)) %>%
  arrange(participantId, ts) %>%
  distinct(participantId, blockIndex, trialInBlock, .keep_all = TRUE) %>%
  mutate(choseIndividualAsBF = coalesce(as.numeric(choseIndividualAsBF),
                                        as.numeric(hypothesisConsistent)),
         Age.Decimal = coalesce(as.numeric(age_exact), age + 0.5)) %>%
  filter(age >= 4, age <= 8, !is.na(choseIndividualAsBF))

theme_study <- function() {
  theme_minimal(base_size = 18, base_family = "Avenir Next") +
    theme(panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_blank(),
          panel.grid.minor   = element_blank(),
          axis.line          = element_line(colour = "black", linewidth = 0.6),
          axis.ticks         = element_line(colour = "black"),
          axis.text          = element_text(colour = "black", face = "bold"),
          legend.position    = "bottom")
}

figS2.a <- ggplot(data = dat,
                  aes(x = Age.Decimal, y = choseIndividualAsBF)) +
  geom_hline(yintercept = 0.5, linetype = 2, alpha = 0.6, linewidth = 0.9) +
  geom_jitter(alpha = 0.25, height = 0.05, size = 2.2, colour = "deepskyblue") +
  geom_smooth(method = "glm",
              method.args = list(family = binomial),
              colour = "deepskyblue", fill = "deepskyblue",
              alpha = 0.2, linewidth = 1.6) +
  scale_y_continuous(breaks = c(0, 0.5, 1),
                     labels = c("Said Individual\n Explainer\n Boss", "0.5",
                                "Said Individual\n Explainer\n Best Friend")) +
  scale_x_continuous(breaks = 5:9) +
  ylab(NULL) + xlab("Age (Years)") +
  theme_study()
figS2.a
ggsave("figures_ink/s2_age.png", figS2.a,
       width = 4.8, height = 4, dpi = 300, bg = "white")

# ---- Fig 2: hmm vs yes as separate lines, TWIZZLE_CLEAN.R style ------------
# (colour scheme, typography, legends, and axis text all match the
#  plot_age figures in TWIZZLE_CLEAN.R)
cond_cols <- c(Yes = "#0072B2", Hmm = "#E88A8A")
dat$epistemic <- factor(str_to_title(dat$epistemic), levels = c("Yes", "Hmm"))

figS2.ep.a <- ggplot(dat, aes(Age.Decimal, choseIndividualAsBF,
                              colour = epistemic, fill = epistemic)) +
  geom_hline(aes(yintercept = 0.5, linetype = "Chance (.5)"),
             colour = "black", linewidth = 0.6) +
  geom_jitter(width = 0.05, height = 0.03, alpha = 0.3, size = 1.5) +
  geom_smooth(aes(linetype = "Children (model)"), method = "glm",
              method.args = list(family = binomial),
              alpha = 0.2, linewidth = 1) +
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
  labs(title = stringr::str_wrap(
         "Study 2: individual explainer chosen as best friend, by age", 40),
       x = "Age (years)", y = "P(choose individual)") +
  theme_study() +
  theme(panel.grid.major.y = element_line(colour = "grey90"),
        plot.title = element_text(size = 14, face = "bold", hjust = 0,
                                  margin = margin(b = 8)),
        plot.title.position = "plot",
        legend.box = "vertical",
        legend.box.just = "center",
        legend.spacing.y = unit(1, "pt"),
        legend.margin = margin(2, 4, 2, 4),
        legend.key.width = unit(1.4, "cm"),
        plot.margin = margin(t = 10, r = 12, b = 6, l = 8))
figS2.ep.a
ggsave("figures_ink/s2_age_epistemic.png", figS2.ep.a,
       width = 6, height = 5.4, dpi = 300, bg = "white")


# ---- Fig 3: continuous-age MIXED MODEL curve, epistemic combined -------------
# brm random-intercept logistic (pre-registered priors); curve + 95% CrI from
# conditional_effects; Twizzle typography.
library(brms)
dat$age_c <- dat$Age.Decimal - mean(dat$Age.Decimal)
fit_age <- brm(choseIndividualAsBF ~ age_c + (1 | participantId), data = dat,
               family = bernoulli(),
               prior = c(prior(normal(0, 1.5), class = "Intercept"),
                         prior(normal(0, 1),   class = "b"),
                         prior(exponential(2), class = "sd")),
               iter = 4000, warmup = 1000, chains = 4, cores = 4,
               seed = 20260731, refresh = 0,
               control = list(adapt_delta = 0.95))
ce <- as.data.frame(conditional_effects(fit_age, effects = "age_c")[[1]]) %>%
  mutate(age = age_c + mean(dat$Age.Decimal))
figS2.agem <- ggplot(ce, aes(age, estimate__)) +
  geom_hline(aes(yintercept = 0.5, linetype = "Chance (.5)"),
             colour = "black", linewidth = 0.6) +
  geom_jitter(data = dat, inherit.aes = FALSE,
              aes(Age.Decimal, choseIndividualAsBF),
              width = 0.05, height = 0.03, alpha = 0.25, size = 1.5,
              colour = "deepskyblue") +
  geom_ribbon(aes(ymin = lower__, ymax = upper__),
              fill = "deepskyblue", alpha = 0.25) +
  geom_line(aes(linetype = "Children (model)"),
            colour = "deepskyblue", linewidth = 1) +
  scale_linetype_manual(name = NULL,
                        values = c("Children (model)" = "solid",
                                   "Chance (.5)"      = "dashed"),
                        guide = guide_legend(override.aes = list(colour = "black"))) +
  scale_y_continuous(labels = scales::percent, breaks = c(0, .5, 1)) +
  scale_x_continuous(breaks = 4:9) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(title = stringr::str_wrap(
         "Study 2: individual explainer chosen as best friend, by age (mixed model)", 42),
       x = "Age (years)", y = "P(choose individual)") +
  theme_minimal(base_size = 18, base_family = "Avenir Next") +
  theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
        panel.grid.major.y = element_line(colour = "grey90"),
        axis.line = element_line(colour = "black", linewidth = 0.6),
        axis.text = element_text(colour = "black", face = "bold"),
        plot.title = element_text(size = 14, face = "bold", hjust = 0),
        plot.title.position = "plot",
        legend.position = "bottom", legend.key.width = unit(1.4, "cm"))
figS2.agem
ggsave("figures_ink/s2_age_combined_model.png", figS2.agem,
       width = 6, height = 5.2, dpi = 300, bg = "white")


# ---- Fig 4: age groups (Younger 5-6 vs Older 7-8), epistemic combined --------
# Bars = mean of per-participant proportions (5-8 confirmatory sample only),
# points = individual children, error bars = 95% CI, stars = directional
# BF+0 vs chance (BayesFactor::ttestBF, nullInterval = c(0, Inf)).
library(BayesFactor)
bf_dir <- function(p) {
  bf <- BayesFactor::ttestBF(x = p, mu = 0.5, nullInterval = c(0, Inf))
  as.numeric(as.vector(bf))[1]
}
bf_star <- function(bf) dplyr::case_when(bf >= 100 ~ "***", bf >= 10 ~ "**",
                                         bf >= 3 ~ "*", TRUE ~ "")
pp <- dat %>%
  dplyr::filter(age >= 5, age <= 8) %>%
  dplyr::group_by(participantId) %>%
  dplyr::summarise(age_dec = first(Age.Decimal),
                   p = mean(choseIndividualAsBF), .groups = "drop") %>%
  dplyr::mutate(grp = factor(ifelse(age_dec < 7, "Younger\n(5\u20136 years)",
                                    "Older\n(7\u20138 years)"),
                             levels = c("Younger\n(5\u20136 years)",
                                        "Older\n(7\u20138 years)")))
cell <- pp %>% dplyr::group_by(grp) %>%
  dplyr::summarise(m = mean(p), se = sd(p)/sqrt(dplyr::n()),
                   star = bf_star(bf_dir(p)), .groups = "drop")
figS2.grp <- ggplot(cell, aes(grp, m)) +
  geom_col(width = 0.62, fill = "deepskyblue", alpha = 0.85,
           colour = "black", linewidth = 1.6) +
  geom_errorbar(aes(ymin = m - 1.96*se, ymax = m + 1.96*se),
                width = 0.15, linewidth = 1.4) +
  geom_jitter(data = pp, aes(grp, p), width = 0.2, height = 0.01,
              alpha = 0.45, size = 2.6, colour = "#1a6e8a") +
  geom_text(aes(y = 1.04, label = star), size = 10, fontface = "bold") +
  geom_hline(yintercept = 0.5, linetype = 2, alpha = 0.6, linewidth = 0.9) +
  scale_y_continuous(breaks = c(0, .25, .5, .75, 1),
                     labels = c("0", "25", "50", "75", "100"),
                     expand = expansion(mult = c(0, 0.08))) +
  labs(x = NULL, y = "% individual explainer chosen as best friend") +
  theme_minimal(base_size = 18) +
  theme(legend.position = "none",
        panel.grid = element_blank(),
        panel.background = element_rect(fill = "white", colour = NA),
        plot.background = element_rect(fill = "white", colour = NA),
        axis.line = element_line(colour = "grey30", linewidth = 0.6),
        axis.ticks = element_line(colour = "grey30", linewidth = 0.6),
        axis.text = element_text(colour = "black", face = "bold", size = 16),
        axis.title.y = element_text(size = 16, face = "bold",
                                    margin = margin(r = 10)))
figS2.grp
ggsave("figures_ink/s2_agegroups_bar.png", figS2.grp,
       width = 5.6, height = 5.8, dpi = 300, bg = "white")

message("Study 2 ink-style age figure written to figures_ink/s2_age.png")
