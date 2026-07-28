import sys, time, numpy as np, pandas as pd
sys.path.insert(0, "/sessions/optimistic-zen-sagan/mnt/outputs/relkind_run")
from common import *

name = sys.argv[1]
warmup = int(sys.argv[2]) if len(sys.argv) > 2 else 750
samples = int(sys.argv[3]) if len(sys.argv) > 3 else 750
chains = int(sys.argv[4]) if len(sys.argv) > 4 else 4

d = load_dat()
t0 = time.time()
if name == "m_main":
    dd, kw = d, dict(kind="full")
elif name == "m_younger":
    dd, kw = d[d.ageGroup == "Younger"], dict(kind="2way")
elif name == "m_older":
    dd, kw = d[d.ageGroup == "Older"], dict(kind="2way")
elif name == "m_sens_age_continuous":
    dd, kw = d, dict(kind="full", age_col="age_c")
elif name == "m_sens_priors_tight":
    dd, kw = d, dict(kind="full", b_sd=0.5)
elif name == "m_sens_priors_wide":
    dd, kw = d, dict(kind="full", b_sd=2.5)
elif name == "m_sens_complete_only":
    n = d.groupby("participantId")["y"].size()
    dd, kw = d[d.participantId.isin(n[n == 12].index)], dict(kind="full")
elif name == "m_sens_6_with_older":
    d = d.copy()
    d["ag"] = np.where(d["age"] < 6, 1.0, -1.0)
    dd, kw = d, dict(kind="full")
else:
    raise SystemExit("unknown model")

mcmc, names = fit(dd, warmup=warmup, samples=samples, chains=chains, **kw)
res = summarize(mcmc, names, b_sd=kw.get("b_sd", 1.0))
res.insert(0, "model", name)
res.to_csv(f"{OUT}/tables_bayes_py/{name}_posterior.csv", index=False)
print(res.to_string(index=False))
print(f"\n{name}: n_participants={dd.participantId.nunique()} n_trials={len(dd)} elapsed={time.time()-t0:.0f}s")
