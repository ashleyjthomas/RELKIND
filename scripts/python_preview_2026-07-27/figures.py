import sys
sys.path.insert(0, "/sessions/optimistic-zen-sagan/mnt/outputs/relkind_run")
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from common import load_dat, OUT

d = load_dat()
pp = (d.groupby(['participantId','ageGroup','questionType','epistemic'])
        .agg(p=('y','mean')).reset_index())
colors = {'close': '#3498db', 'boss': '#e67e22'}

def panel(ax, sub, title):
    xs = np.arange(2)  # hmm, yes
    w = 0.35
    for i, qt in enumerate(['close','boss']):
        m, se = [], []
        for ep in ['hmm','yes']:
            x = sub[(sub.questionType==qt)&(sub.epistemic==ep)]['p']
            m.append(x.mean()); se.append(x.std(ddof=1)/np.sqrt(len(x)))
        pos = xs + (i-0.5)*w
        ax.bar(pos, m, w*0.92, color=colors[qt], alpha=0.85, label=qt)
        ax.errorbar(pos, m, yerr=1.96*np.array(se), fmt='none', ecolor='k', capsize=4, lw=1.2)
    ax.axhline(0.5, ls='--', c='grey')
    ax.set_xticks(xs); ax.set_xticklabels(['hmm','yes'])
    ax.set_ylim(0, 1.05); ax.set_title(title, fontsize=11)
    ax.spines[['top','right']].set_visible(False)

fig, ax = plt.subplots(figsize=(6,4))
panel(ax, pp, "Hypothesis-consistent responding (ages 5-8)")
ax.set_ylabel("P(hypothesis-consistent)"); ax.set_xlabel("Epistemic certainty")
ax.legend(title="Question", frameon=False)
fig.tight_layout(); fig.savefig(f"{OUT}/figures_bayes_py/01_cell_means.png", dpi=200)

fig, axes = plt.subplots(1, 2, figsize=(9,4), sharey=True)
panel(axes[0], pp[pp.ageGroup=='Younger'], "Younger (5-6 yrs)")
panel(axes[1], pp[pp.ageGroup=='Older'], "Older (7-8 yrs)")
axes[0].set_ylabel("P(hypothesis-consistent)")
for a in axes: a.set_xlabel("Epistemic certainty")
axes[1].legend(title="Question", frameon=False)
fig.suptitle("Hypothesis-consistent responding by age group", y=1.0)
fig.tight_layout(); fig.savefig(f"{OUT}/figures_bayes_py/02_cell_means_by_agegroup.png", dpi=200)

# Interpretation figure: P(choose individual-explainer) by question x age
d['choseInd'] = (d.chosenRole=='individual').astype(int)
ppi = (d.groupby(['participantId','ageGroup','questionType'])
         .agg(p=('choseInd','mean')).reset_index())
fig, ax = plt.subplots(figsize=(6,4))
xs = np.arange(2)  # younger, older
w = 0.35
for i, qt in enumerate(['close','boss']):
    m, se = [], []
    for agrp in ['Younger','Older']:
        x = ppi[(ppi.questionType==qt)&(ppi.ageGroup==agrp)]['p']
        m.append(x.mean()); se.append(x.std(ddof=1)/np.sqrt(len(x)))
    pos = xs + (i-0.5)*w
    ax.bar(pos, m, w*0.92, color=colors[qt], alpha=0.85,
           label='best friend' if qt=='close' else 'boss')
    ax.errorbar(pos, m, yerr=1.96*np.array(se), fmt='none', ecolor='k', capsize=4, lw=1.2)
ax.axhline(0.5, ls='--', c='grey')
ax.set_xticks(xs); ax.set_xticklabels(['Younger (5-6)','Older (7-8)'])
ax.set_ylim(0,1.05); ax.set_ylabel("P(choose individual-explainer)")
ax.set_title("Choice of the individuating speaker, by question")
ax.legend(title="Question asked", frameon=False)
ax.spines[['top','right']].set_visible(False)
fig.tight_layout(); fig.savefig(f"{OUT}/figures_bayes_py/03_individual_choice_rate.png", dpi=200)
print("figures saved")
