import sys, numpy as np, pandas as pd
sys.path.insert(0, "/sessions/optimistic-zen-sagan/mnt/outputs/relkind_run")
from common import load_dat, OUT
from scipy import integrate, stats

R_SCALE = np.sqrt(2) / 2  # ttestBF default rscale

def jzs_bf(x, mu=0.5, interval=None, r=R_SCALE):
    """One-sample JZS BF. interval=(lo,hi) on delta restricts the alternative
    (BayesFactor nullInterval semantics; returns BF_interval vs point null)."""
    x = np.asarray(x, float)
    N = len(x); nu = N - 1
    t = (x.mean() - mu) / (x.std(ddof=1) / np.sqrt(N))
    null_lik = stats.t.pdf(t, nu)
    f = lambda d: stats.nct.pdf(t, nu, d * np.sqrt(N)) * stats.cauchy.pdf(d, 0, r)
    if interval is None:
        num, _ = integrate.quad(f, -np.inf, np.inf)
        prior_mass = 1.0
    else:
        num, _ = integrate.quad(f, interval[0], interval[1])
        prior_mass = stats.cauchy.cdf(interval[1], 0, r) - stats.cauchy.cdf(interval[0], 0, r)
    return (num / prior_mass) / null_lik, t

d = load_dat()
pp = (d.groupby(['participantId', 'ageGroup', 'questionType', 'epistemic'])
        .agg(p_hypothesis=('y', 'mean'), n_trials=('y', 'size')).reset_index())
pp.to_csv(f"{OUT}/tables_bayes_py/per_participant_cell_means.csv", index=False)

def cell_table(groupcols):
    rows = []
    for keys, g in pp.groupby(groupcols):
        x = g['p_hypothesis'].values
        keys = keys if isinstance(keys, tuple) else (keys,)
        row = dict(zip(groupcols, keys))
        row.update(n=len(x), mean_p=x.mean(), sd=x.std(ddof=1))
        if len(x) > 2 and x.std() > 0:
            bf_prereg, t = jzs_bf(x, interval=(0.5, 1))     # exactly as pre-registered
            bf_dir, _ = jzs_bf(x, interval=(0, np.inf))     # conventional directional
            bf_two, _ = jzs_bf(x)                            # two-sided
            row.update(t=t, bf_prereg_interval_05_1=bf_prereg,
                       bf_directional_0_inf=bf_dir, bf_two_sided=bf_two)
        # 95% CI on mean
        se = x.std(ddof=1)/np.sqrt(len(x))
        row.update(ci_lo=x.mean()-1.96*se, ci_hi=x.mean()+1.96*se)
        rows.append(row)
    return pd.DataFrame(rows)

overall = cell_table(['questionType', 'epistemic'])
by_age = cell_table(['ageGroup', 'questionType', 'epistemic'])
overall.to_csv(f"{OUT}/tables_bayes_py/chance_tests_per_cell.csv", index=False)
by_age.to_csv(f"{OUT}/tables_bayes_py/chance_tests_by_age.csv", index=False)
pd.set_option('display.width', 200)
print("=== Overall (hypothesis-consistent choice rate vs 0.5) ===")
print(overall.round(3).to_string(index=False))
print("\n=== By age group ===")
print(by_age.round(3).to_string(index=False))
