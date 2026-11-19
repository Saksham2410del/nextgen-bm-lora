import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.ensemble import IsolationForest
from sklearn.metrics import precision_score, recall_score, f1_score

# node is critical when its reading is outside its own normal range
# isolation forest is compared with a fixed threshold rule

s = open('../data/split.txt').read().split()
T, n_train = int(s[0]), int(s[1])
data = pd.read_csv('../data/frames.csv')
feats = ['temperature', 'humidity', 'voltage']

train = data[data['frame'] < n_train]
test_mask = (data['frame'] >= n_train).values

# normal range of every node from train part
# median and MAD are used instead of mean and std so broken readings dont spoil it
med = train.groupby('moteid')[feats].median()
mad = train.groupby('moteid')[feats].apply(lambda x: (x - x.median()).abs().median() * 1.4826)

z = (data.set_index('moteid')[feats] - med) / mad
z = z.values

# reference labels (no labels in dataset) - 3 sigma rule on each node
ref = (np.abs(z) > 3).any(axis=1)
print('reference unusual readings: train %.2f %%, test %.2f %%' % (100 * ref[~test_mask].mean(), 100 * ref[test_mask].mean()))

# fixed threshold rule - same limits for every node
g_med = train[feats].median()
g_mad = (train[feats] - g_med).abs().median() * 1.4826
fixed = ((data[feats] - g_med).abs() > 3 * g_mad).any(axis=1).values

# isolation forest, about 1 % of train readings are unusual so contamination = 0.01
iso = IsolationForest(n_estimators=100, contamination=0.01, random_state=1)
iso.fit(z[~test_mask])
flag = iso.predict(z) == -1

res = []
for name, pred in [('Fixed threshold', fixed), ('Isolation Forest', flag)]:
    p = precision_score(ref[test_mask], pred[test_mask])
    r = recall_score(ref[test_mask], pred[test_mask])
    f = f1_score(ref[test_mask], pred[test_mask])
    rate = pred[test_mask].mean()
    res.append([name, p, r, f, rate])
    print('%-17s precision %.3f  recall %.3f  F1 %.3f  flagged %.2f %%' % (name, p, r, f, 100 * rate))

out = pd.DataFrame(res, columns=['model', 'precision', 'recall', 'f1', 'flag_rate'])
out.to_csv('../results/ml/criticality_results.csv', index=False)

data['critical'] = flag.astype(int)
data[['frame', 'moteid', 'critical']].to_csv('../data/critical_flags.csv', index=False)

# bar plot
x = np.arange(3)
plt.figure(figsize=(6, 4))
plt.bar(x - 0.2, out.iloc[0, 1:4], 0.4, label='Fixed threshold')
plt.bar(x + 0.2, out.iloc[1, 1:4], 0.4, label='Isolation Forest')
plt.xticks(x, ['Precision', 'Recall', 'F1 score'])
plt.ylim(0, 1)
plt.ylabel('Score')
plt.title('Criticality classifier (test data)')
plt.legend()
plt.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig('../results/ml/criticality_comparison.png', dpi=150)

# one node as example
m = data.loc[test_mask & flag, 'moteid'].value_counts().index[0]
d = data[data['moteid'] == m]
fl = d['critical'] == 1
fig, ax = plt.subplots(2, 1, figsize=(8, 5), sharex=True)
ax[0].plot(d['frame'], d['temperature'], lw=0.8)
ax[0].scatter(d.loc[fl, 'frame'], d.loc[fl, 'temperature'], color='red', s=10, label='critical')
ax[0].set_ylabel('Temperature (C)')
ax[0].legend()
ax[1].plot(d['frame'], d['voltage'], lw=0.8)
ax[1].scatter(d.loc[fl, 'frame'], d.loc[fl, 'voltage'], color='red', s=10)
ax[1].set_ylabel('Voltage (V)')
ax[1].set_xlabel('Frame (10 min)')
ax[0].axvline(n_train, color='k', ls='--', lw=0.8)
ax[1].axvline(n_train, color='k', ls='--', lw=0.8)
ax[0].set_title('Mote %d - readings marked critical by Isolation Forest' % m)
plt.tight_layout()
plt.savefig('../results/ml/critical_example_mote.png', dpi=150)
print('saved results/ml/criticality_*.png')
