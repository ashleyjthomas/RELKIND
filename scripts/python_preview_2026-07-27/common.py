"""Shared data prep + model code replicating analyze_twizzle_bayes.R in numpyro."""
import numpy as np
import pandas as pd
import jax, jax.numpy as jnp
import numpyro
import numpyro.distributions as dist
from numpyro.infer import MCMC, NUTS

numpyro.set_host_device_count(4)

DATA = "/sessions/optimistic-zen-sagan/mnt/outputs/relkind_run/twizzle_data.csv"
OUT = "/sessions/optimistic-zen-sagan/mnt/outputs/relkind_run"

def load_dat(min_age=5, max_age=8):
    raw = pd.read_csv(DATA)
    d = raw.copy()
    d = d[~d['participantId'].astype(str).str.upper().isin(['TEST','TESTING','PILOT'])]
    d = d[~d['firstName'].astype(str).str.upper().isin(['TEST','TESTING','PILOT'])]
    d = d.sort_values(['participantId','timestamp'])
    d = d.drop_duplicates(subset=['participantId','dataExportTag'])
    d['age'] = pd.to_numeric(d['age'])
    d = d[(d['age'] >= min_age) & (d['age'] <= max_age + 0.999)]
    d['ageGroup'] = np.where(d['age'] < 7, 'Younger', 'Older')
    d['age_c'] = d['age'] - d['age'].mean()
    # sum coding matching R contr.sum with levels (close,boss),(hmm,yes),(Younger,Older)
    d['qT'] = np.where(d['questionType'] == 'close', 1.0, -1.0)   # boss_vs_close col: close=+1
    d['ep'] = np.where(d['epistemic'] == 'hmm', 1.0, -1.0)        # yes_vs_hmm col: hmm=+1
    d['ag'] = np.where(d['ageGroup'] == 'Younger', 1.0, -1.0)     # older_vs_younger col: Younger=+1
    d['y'] = d['hypothesisConsistent'].astype(int)
    return d

TERM_NAMES_FULL = ["Intercept","questionType1","epistemic1","ageGroup1",
                   "questionType1:epistemic1","questionType1:ageGroup1",
                   "epistemic1:ageGroup1","questionType1:epistemic1:ageGroup1"]
TERM_NAMES_2WAY = ["Intercept","questionType1","epistemic1","questionType1:epistemic1"]

def design(d, kind="full", age_col='ag'):
    q, e = d['qT'].values, d['ep'].values
    if kind == "full":
        a = d[age_col].values
        X = np.column_stack([np.ones(len(d)), q, e, a, q*e, q*a, e*a, q*e*a])
        names = list(TERM_NAMES_FULL)
        if age_col == 'age_c':
            names = [n.replace('ageGroup1','age_c') for n in names]
    else:
        X = np.column_stack([np.ones(len(d)), q, e, q*e])
        names = list(TERM_NAMES_2WAY)
    return X, names

def model(X, pid, Zq, Ze, P, y=None, b_sd=1.0):
    K = X.shape[1]
    b0 = numpyro.sample("Intercept", dist.Normal(0, 1.5))
    b = numpyro.sample("b", dist.Normal(0, b_sd).expand([K-1]))
    beta = jnp.concatenate([jnp.array([b0]), b])
    sds = numpyro.sample("sd", dist.Exponential(2.0).expand([3]))
    L = numpyro.sample("L", dist.LKJCholesky(3, 1.0))
    z = numpyro.sample("z", dist.Normal(0, 1).expand([P, 3]))
    u = (z @ (sds[:, None] * L).T)  # P x 3
    eta = X @ beta + u[pid, 0] + u[pid, 1]*Zq + u[pid, 2]*Ze
    numpyro.sample("y", dist.Bernoulli(logits=eta), obs=y)

def fit(d, kind="full", age_col='ag', b_sd=1.0, seed=20260619,
        warmup=1000, samples=1000, chains=4):
    X, names = design(d, kind, age_col)
    pids = pd.Categorical(d['participantId']).codes
    mcmc = MCMC(NUTS(model, target_accept_prob=0.95),
                num_warmup=warmup, num_samples=samples, num_chains=chains,
                chain_method='parallel', progress_bar=False)
    mcmc.run(jax.random.PRNGKey(seed), X=jnp.array(X), pid=jnp.array(pids),
             Zq=jnp.array(d['qT'].values), Ze=jnp.array(d['ep'].values),
             P=int(pids.max()) + 1, y=jnp.array(d['y'].values), b_sd=b_sd)
    return mcmc, names

def summarize(mcmc, names, b_sd=1.0):
    from scipy.stats import gaussian_kde, norm
    post = mcmc.get_samples(group_by_chain=True)
    b0 = np.asarray(post['Intercept'])            # C x S
    b = np.asarray(post['b'])                     # C x S x (K-1)
    draws = np.concatenate([b0[..., None], b], axis=-1)  # C x S x K
    flat = draws.reshape(-1, draws.shape[-1])
    # rhat
    C, S, K = draws.shape
    rows = []
    for k in range(K):
        x = draws[:, :, k]
        W = x.var(axis=1, ddof=1).mean()
        Bv = S * x.mean(axis=1).var(ddof=1) if C > 1 else 0.0
        rhat = np.sqrt(((S-1)/S*W + Bv/S) / W) if C > 1 else np.nan
        v = flat[:, k]
        lo, hi = np.percentile(v, [2.5, 97.5])
        pd_dir = max((v > 0).mean(), (v < 0).mean())
        # Savage-Dickey BF10 vs prior at 0
        prior_sd = 1.5 if names[k] == "Intercept" else b_sd
        try:
            post0 = gaussian_kde(v)(0.0)[0]
            bf10 = norm.pdf(0, 0, prior_sd) / post0
        except Exception:
            bf10 = np.nan
        rows.append(dict(term=names[k], median=np.median(v), mean=v.mean(),
                         ci_lo=lo, ci_hi=hi, pd=pd_dir, bf10_savage_dickey=bf10,
                         rhat=rhat))
    return pd.DataFrame(rows)
