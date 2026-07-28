import sys, numpy as np, pandas as pd
sys.path.insert(0, "/sessions/optimistic-zen-sagan/mnt/outputs/relkind_run")
from common import load_dat, fit, summarize, OUT

# --- build exact-age table -----------------------------------
ages = pd.read_csv(f"{OUT}/ages_exact.csv")
ages['age_exact'] = pd.to_numeric(ages['age_exact'])
# reject implausible DOB (parent's own DOB etc.): |exact - reported| > 2 yrs
bad = ages['age_exact'].notna() & ((ages['age_exact'] - ages['age_reported']).abs() > 2)
ages.loc[bad, 'age_exact'] = np.nan
ages['age_best'] = ages['age_exact'].fillna(ages['age_reported'] + 0.5)
ages['age_source'] = np.where(ages['age_exact'].notna(), 'DOB', 'reported+0.5')

d = load_dat()  # ages 5-8 on *reported* age
d = d.merge(ages[['participantId', 'age_best', 'age_source']], on='participantId', how='left')

# age window check on exact age: anyone now outside 5.00-8.99?
per = d.groupby('participantId').agg(age_rep=('age', 'first'), age_best=('age_best', 'first'),
                                     src=('age_source', 'first')).reset_index()
out_of_window = per[(per.age_best < 5) | (per.age_best >= 9)]
print("Outside 5.00-8.99 by exact age:\n", out_of_window.to_string(index=False))
print("\nRetained per year (floor of best age):")
print(per['age_best'].apply(np.floor).value_counts().sort_index())

# use exact age; keep prereg window on reported age (flag only)
d['age_c'] = d['age_best'] - d['age_best'].mean()
AGE_MEAN = d['age_best'].mean()
print("\nage mean:", round(AGE_MEAN, 3))

mcmc, names = fit(d, kind="full", age_col='age_c')
res = summarize(mcmc, names)
res.insert(0, 'model', 'm_age_exact_continuous')
res.to_csv(f"{OUT}/tables_bayes_py/m_age_exact_continuous_posterior.csv", index=False)
print(res.round(3).to_string(index=False))

# save draws for plotting curves
post = mcmc.get_samples()
np.savez(f"{OUT}/age_model_draws.npz",
         Intercept=np.asarray(post['Intercept']), b=np.asarray(post['b']),
         age_mean=AGE_MEAN, names=np.array(names))
per.to_csv(f"{OUT}/tables_bayes_py/participant_exact_ages.csv", index=False)
d.to_csv(f"{OUT}/twizzle_data_with_exact_age.csv", index=False)
print("\nsaved draws + data")
