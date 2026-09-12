# ============================================================================
#  relkind_s1_age_figures_ink.R
#  RELKIND Study 1: developmental (age) figures in the INK house style
#  (matches the "by age (continuous)" figures in inkfull-240624.R:
#   binomial geom_smooth + jittered raw responses, deepskyblue, white panel,
#   thin grey axis lines, dashed chance line at 0.5)
#
#  DV: choseInd = 1 if the child chose the INDIVIDUAL-level explainer
#  (transparent coding; equals hypothesisConsistent on close trials and
#  1 - hypothesisConsistent on boss trials).
#
#  INPUTS (next to this script):
#    study1_data.csv          full Study 1 game export
#    python_preview_2026-07-27/tables_bayes_py/participant_exact_ages.csv
#                              (optional; exact ages from CHS birthdates)
#  OUTPUT: figures_ink/*.png
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

# ---- data: Study 1 confirmatory sample (same rules as the main analysis) ----
raw <- read_csv("study1_data.csv", show_col_types = FALSE)

dat <- raw %>%
  mutate(ts = ymd_hms(timestamp),
         fn = str_to_upper(str_trim(as.character(firstName)))) %>%
  filter(!fn %in% c("TEST", "TESTING", "NAN"),
         !str_to_upper(participantId) %in% c("TEST", "TESTING")) %>%
  group_by(participantId) %>% mutate(t0 = min(ts)) %>% ungroup() %>%
  filter(t0 >= ymd_hms("2026-06-19 18:00:00")) %>%          # post-registration
  arrange(t0) %>%
  group_by(fn, age) %>%                                      # duplicate sessions:
  filter(participantId == first(participantId)) %>%          # keep first
  ungroup() %>%
  distinct(participantId, dataExportTag, .keep_all = TRUE) %>%
  filter(age >= 5, age <= 8)

# exact ages (CHS birthdates) where available; else age + 0.5
ages_path <- file.path("python_preview_2026-07-27", "tables_bayes_py",
                       "participant_exact_ages.csv")
if (file.exists(ages_path)) {
  exact <- read_csv(ages_path, show_col_types = FALSE) %>%
    select(participantId, age_best)
  dat <- left_join(dat, exact, by = "participantId")
} else dat$age_best <- NA_real_
dat <- dat %>%
  mutate(Age.Decimal = coalesce(age_best, age + 0.5),
         choseInd    = as.numeric(chosenRole == "individual"))

# ---- INK style block (from inkfull-240624.R) --------------------------------
theme_ink <- theme(legend.position = "none",
                   panel.background = element_rect(fill = "white"),
                   axis.line = element_line(colour = "grey", size = .25))

# ---- Fig 1: best-friend question, by age (continuous) -----------------------
figS1.bf.a <- ggplot(data = dplyr::filter(dat, questionType == "close"),
                     aes(x = Age.Decimal, y = choseInd,
                         fill = "deepskyblue", color = "deepskyblue")) +
  geom_smooth(method = "glm",
              method.args = list(family = binomial)) +
  geom_jitter(alpha = 0.25, height = 0.05) +
  scale_color_manual(values = c("deepskyblue")) +
  scale_fill_manual(values = c("deepskyblue")) +
  theme_ink +
  ylab("Individual Explainer is Best Friend") + xlab("Age (Years)") +
  geom_hline(yintercept = 0.5, linetype = 2, alpha = 0.5)
figS1.bf.a
ggsave("figures_ink/s1_bestfriend_age.png", figS1.bf.a,
       width = 4.8, height = 4, dpi = 300, bg = "white")

# ---- Fig 2: boss question, by age (continuous) -------------------------------
figS1.boss.a <- ggplot(data = dplyr::filter(dat, questionType == "boss"),
                       aes(x = Age.Decimal, y = choseInd,
                           fill = "deepskyblue", color = "deepskyblue")) +
  geom_smooth(method = "glm",
              method.args = list(family = binomial)) +
  geom_jitter(alpha = 0.25, height = 0.05) +
  scale_color_manual(values = c("deepskyblue")) +
  scale_fill_manual(values = c("deepskyblue")) +
  theme_ink +
  ylab("Individual Explainer is Boss") + xlab("Age (Years)") +
  geom_hline(yintercept = 0.5, linetype = 2, alpha = 0.5)
figS1.boss.a
ggsave("figures_ink/s1_boss_age.png", figS1.boss.a,
       width = 4.8, height = 4, dpi = 300, bg = "white")

# ---- Fig 3: both questions overlaid (two-condition ink style) ----------------
dat$Question <- factor(ifelse(dat$questionType == "close", "Best Friend", "Boss"),
                       levels = c("Best Friend", "Boss"))
figS1.both.a <- ggplot(data = dat,
                       aes(x = Age.Decimal, y = choseInd,
                           group = Question, color = Question, fill = Question)) +
  geom_smooth(method = "glm",
              method.args = list(family = binomial)) +
  geom_jitter(alpha = 0.25, height = 0.05) +
  scale_color_manual(values = c("deepskyblue", "khaki3")) +
  scale_fill_manual(values = c("deepskyblue", "khaki3")) +
  theme(legend.position = "bottom",
        panel.background = element_rect(fill = "white"),
        axis.line = element_line(colour = "grey", size = .25)) +
  ylab("Chose Individual Explainer") + xlab("Age (Years)") +
  geom_hline(yintercept = 0.5, linetype = 2, alpha = 0.5)
figS1.both.a
ggsave("figures_ink/s1_bothquestions_age.png", figS1.both.a,
       width = 5.2, height = 4.8, dpi = 300, bg = "white")

# ---- Figs 4-5: best-friend question split by epistemic frame ----------------
# (each child saw ONE epistemic frame per block, so these are between-subject
#  subsets: "Hmm" n ~ 64 kids, "Yes" n ~ 63 kids)
for (ep in c("hmm", "yes")) {
  fig <- ggplot(data = dplyr::filter(dat, questionType == "close",
                                     epistemic == ep),
                aes(x = Age.Decimal, y = choseInd,
                    fill = "deepskyblue", color = "deepskyblue")) +
    geom_smooth(method = "glm",
                method.args = list(family = binomial)) +
    geom_jitter(alpha = 0.25, height = 0.05) +
    scale_color_manual(values = c("deepskyblue")) +
    scale_fill_manual(values = c("deepskyblue")) +
    theme_ink +
    ylab("Individual Explainer is Best Friend") + xlab("Age (Years)") +
    labs(title = paste0('"', str_to_title(ep), '" trials')) +
    geom_hline(yintercept = 0.5, linetype = 2, alpha = 0.5)
  print(fig)
  ggsave(paste0("figures_ink/s1_bestfriend_age_", ep, ".png"), fig,
         width = 4.8, height = 4, dpi = 300, bg = "white")
}

message("Ink-style age figures written to figures_ink/")
