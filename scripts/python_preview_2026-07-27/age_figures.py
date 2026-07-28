import sys
sys.path.insert(0, "/sessions/optimistic-zen-sagan/mnt/outputs/relkind_run")
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from common import OUT

d = pd.read_csv(f"{OUT}/twizzle_data_with_exact_age.csv")
z = np.load(f"{OUT}/age_model_draws.npz", allow_pickle=True)
b0, b, age_mean = z['Intercept'], z['b'], float(z['age_mean'])
# b columns: qT, ep, age, qT*ep, qT*age, ep*age, qT*ep*age
sig = lambda x: 1/(1+np.exp(-x))
ages = np.linspace(5, 9, 81)
ac = ages - age_mean

def curve(q):  # epistemic at 0 (averaged)
    eta = (b0[:, None] + b[:, 0:1]*q + b[:, 2:3]*ac[None, :] + b[:, 4:5]*q*ac[None, :])
    p = sig(eta)
    return p.mean(0), np.percentile(p, 2.5, 0), np.percentile(p, 97.5, 0)

pp = (d.groupby(['participantId', 'age_best', 'questionType'])
        .agg(p=('y', 'mean'), n=('y', 'size')).reset_index())
colors = {'close': '#3498db', 'boss': '#e67e22'}
labels = {'close': 'best friend', 'boss': 'boss'}

fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), sharey=True)

# Panel A: hypothesis-consistent
ax = axes[0]
rng = np.random.default_rng(1)
for qt, q in [('close', 1.0), ('boss', -1.0)]:
    s = pp[pp.questionType == qt]
    ax.scatter(s.age_best + rng.uniform(-.03, .03, len(s)), s.p, s=22, alpha=.45,
               color=colors[qt], edgecolors='none', label=None)
    m, lo, hi = curve(q)
    ax.plot(ages, m, color=colors[qt], lw=2.5, label=labels[qt])
    ax.fill_between(ages, lo, hi, color=colors[qt], alpha=.18)
ax.axhline(.5, ls='--', c='grey', lw=1)
ax.set_xlabel("Age (years, from birthdate)")
ax.set_ylabel("P(hypothesis-consistent)")
ax.set_title("A. Hypothesis-consistent responding by age")
ax.legend(title="Question", frameon=False, loc='lower right')

# Panel B: P(choose individual-explainer); boss = 1 - consistent
ax = axes[1]
for qt, q in [('close', 1.0), ('boss', -1.0)]:
    s = pp[pp.questionType == qt].copy()
    y = s.p if qt == 'close' else 1 - s.p
    ax.scatter(s.age_best + rng.uniform(-.03, .03, len(s)), y, s=22, alpha=.45,
               color=colors[qt], edgecolors='none')
    m, lo, hi = curve(q)
    if qt == 'boss':
        m, lo, hi = 1-m, 1-hi, 1-lo
    ax.plot(ages, m, color=colors[qt], lw=2.5, label=labels[qt])
    ax.fill_between(ages, lo, hi, color=colors[qt], alpha=.18)
ax.axhline(.5, ls='--', c='grey', lw=1)
ax.set_xlabel("Age (years, from birthdate)")
ax.set_ylabel("P(choose individual-explainer)")
ax.set_title("B. Choice of individuating speaker by age")
ax.legend(title="Question", frameon=False, loc='lower right')

for ax in axes:
    ax.set_ylim(-.03, 1.03); ax.set_xlim(4.9, 9.1)
    ax.spines[['top', 'right']].set_visible(False)
fig.suptitle("RELKIND: age effects with exact (birthdate-derived) ages — points = participants, bands = 95% CrI",
             y=1.02, fontsize=11)
fig.tight_layout()
fig.savefig(f"{OUT}/figures_bayes_py/04_age_continuous.png", dpi=200, bbox_inches='tight')
print("saved 04_age_continuous.png")
