import os
import time
import warnings
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import torch
import torch.nn as nn
from sklearn.ensemble import RandomForestClassifier
from statsmodels.tsa.arima.model import ARIMA

warnings.filterwarnings('ignore')
torch.manual_seed(1)
np.random.seed(1)
torch.set_num_threads(8)

# predict if a node will have data in next frame, from its last K frames
K = 12            # 12 frames = 2 hours of history
LOADS = [1, 2, 3, 4, 5, 6, 7, 8, 9]

s = open('../data/split.txt').read().split()
T, n_train = int(s[0]), int(s[1])
n_val = int(0.9 * n_train)        # last part of train is used for validation

data = pd.read_csv('../data/frames.csv')
motes = sorted(data['moteid'].unique())
M = len(motes)

hour = data[data['moteid'] == motes[0]]['hour'].values
score = data.pivot(index='frame', columns='moteid', values='score').values
score = np.minimum(score, 5) / 5          # big jumps are clipped
hs = np.sin(2 * np.pi * hour / 24)
hc = np.cos(2 * np.pi * hour / 24)

A = {}
for L in LOADS:
    A[L] = data.pivot(index='frame', columns='moteid', values='A_' + str(L)).values


def make_xy(L, t_from, t_to):
    # input = last K frames of [has data, score, sin hour, cos hour]
    X, y = [], []
    for t in range(max(t_from, K), t_to):
        for j in range(M):
            f = np.stack([A[L][t-K:t, j], score[t-K:t, j], hs[t-K:t], hc[t-K:t]], axis=1)
            X.append(f)
            y.append(A[L][t, j])
    return np.array(X, dtype=np.float32), np.array(y, dtype=np.float32)


def get_metrics(y, p):
    pred = (p > 0.5).astype(int)
    acc = (pred == y).mean()
    rmse = np.sqrt(np.mean((p - y) ** 2))
    fpr = ((pred == 1) & (y == 0)).sum() / max((y == 0).sum(), 1)
    fnr = ((pred == 0) & (y == 1)).sum() / max((y == 1).sum(), 1)
    return acc, rmse, fpr, fnr


print('making training data ...')
Xtr, ytr, Xva, yva, Xte, yte, lte = [], [], [], [], [], [], []
for L in LOADS:
    x, y = make_xy(L, 0, n_val)
    Xtr.append(x); ytr.append(y)
    x, y = make_xy(L, n_val, n_train)
    Xva.append(x); yva.append(y)
    x, y = make_xy(L, n_train, T)
    Xte.append(x); yte.append(y); lte.append(np.full(len(y), L))
Xtr = np.concatenate(Xtr); ytr = np.concatenate(ytr)
Xva = np.concatenate(Xva); yva = np.concatenate(yva)
Xte = np.concatenate(Xte); yte = np.concatenate(yte); lte = np.concatenate(lte)
print('train', Xtr.shape, ' val', Xva.shape, ' test', Xte.shape)


# ---------------- GRU ----------------
class GRUNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.gru = nn.GRU(input_size=4, hidden_size=64, num_layers=2, batch_first=True)
        self.fc = nn.Linear(64, 1)

    def forward(self, x):
        out, h = self.gru(x)
        return self.fc(out[:, -1, :]).squeeze(1)


model = GRUNet()
opt = torch.optim.Adam(model.parameters(), lr=0.001)
loss_fn = nn.BCEWithLogitsLoss()

xt = torch.tensor(Xtr); yt = torch.tensor(ytr)
xv = torch.tensor(Xva); yv = torch.tensor(yva)

best = 1e9
hist = []
start = time.time()
for ep in range(15):
    model.train()
    idx = torch.randperm(len(xt))
    tot = 0
    for i in range(0, len(xt), 1024):
        b = idx[i:i+1024]
        opt.zero_grad()
        loss = loss_fn(model(xt[b]), yt[b])
        loss.backward()
        opt.step()
        tot += loss.item() * len(b)
    model.eval()
    with torch.no_grad():
        vl = loss_fn(model(xv), yv).item()
    hist.append([ep + 1, tot / len(xt), vl])
    print('epoch %2d  train loss %.4f  val loss %.4f' % (ep + 1, tot / len(xt), vl))
    if vl < best:
        best = vl
        torch.save(model.state_dict(), '../results/ml/gru_model.pt')
print('training time %.0f s' % (time.time() - start))

model.load_state_dict(torch.load('../results/ml/gru_model.pt'))
model.eval()
with torch.no_grad():
    p_gru = torch.sigmoid(model(torch.tensor(Xte))).numpy()

hist = pd.DataFrame(hist, columns=['epoch', 'train_loss', 'val_loss'])
hist.to_csv('../results/ml/gru_training_history.csv', index=False)
plt.figure(figsize=(6, 4))
plt.plot(hist['epoch'], hist['train_loss'], '-o', label='train')
plt.plot(hist['epoch'], hist['val_loss'], '-s', label='validation')
plt.xlabel('Epoch'); plt.ylabel('BCE loss'); plt.title('GRU training')
plt.legend(); plt.grid(alpha=0.3); plt.tight_layout()
plt.savefig('../results/ml/gru_training_loss.png', dpi=150)

# ---------------- baselines ----------------
# persistence: next frame same as last frame
p_pers = Xte[:, -1, 0]

# random forest on the same inputs (flattened)
print('training random forest ...')
sel = np.random.choice(len(Xtr), 200000, replace=False)
rf = RandomForestClassifier(n_estimators=100, max_depth=12, n_jobs=-1, random_state=1)
rf.fit(Xtr[sel].reshape(len(sel), -1), ytr[sel])
p_rf = rf.predict_proba(Xte.reshape(len(Xte), -1))[:, 1]

# ARIMA(2,0,0) for every node and load, fitted on train part
print('fitting ARIMA models ...')
p_arima = []
for L in LOADS:
    pl = np.zeros((T - n_train, M))
    for j in range(M):
        y = A[L][:, j].astype(float)
        if y[:n_train].std() == 0:
            pl[:, j] = y[n_train - 1]
            continue
        res = ARIMA(y[:n_train], order=(2, 0, 0)).fit()
        res = res.apply(y)
        pl[:, j] = res.predict(start=n_train, end=T - 1)
    p_arima.append(pl.reshape(-1))
p_arima = np.clip(np.concatenate(p_arima), 0, 1)

# ---------------- results ----------------
models = {'Persistence': p_pers, 'ARIMA': p_arima, 'Random Forest': p_rf, 'GRU': p_gru}
rows = []
for name, p in models.items():
    acc, rmse, fpr, fnr = get_metrics(yte, p)
    rows.append([name, 'all', acc, rmse, fpr, fnr])
    for L in LOADS:
        k = lte == L
        acc, rmse, fpr, fnr = get_metrics(yte[k], p[k])
        rows.append([name, L / 10, acc, rmse, fpr, fnr])
res = pd.DataFrame(rows, columns=['model', 'load', 'accuracy', 'rmse', 'fpr', 'fnr'])
res.to_csv('../results/ml/traffic_prediction_results.csv', index=False)

print('\nTest results (all loads)')
print(res[res['load'] == 'all'].round(4).to_string(index=False))

# accuracy vs load
plt.figure(figsize=(7, 4.5))
for name, mk in zip(models, ['o', 's', '^', 'd']):
    r = res[(res['model'] == name) & (res['load'] != 'all')]
    plt.plot(r['load'].astype(float), r['accuracy'], '-' + mk, label=name)
plt.xlabel('Traffic load p'); plt.ylabel('Accuracy')
plt.title('Traffic prediction accuracy on test data')
plt.legend(); plt.grid(alpha=0.3); plt.tight_layout()
plt.savefig('../results/ml/prediction_accuracy_vs_load.png', dpi=150)

# rmse bar
r = res[res['load'] == 'all']
plt.figure(figsize=(6, 4))
plt.bar(r['model'], r['rmse'], color=['grey', 'tab:orange', 'tab:green', 'tab:blue'])
plt.ylabel('RMSE'); plt.title('Prediction error (all loads)')
plt.grid(axis='y', alpha=0.3); plt.tight_layout()
plt.savefig('../results/ml/prediction_rmse.png', dpi=150)

# example: one node, load 0.5, first 2 days of test
k = (lte == 5)
yy = yte[k].reshape(-1, M)
pp = p_gru[k].reshape(-1, M)
j = 10
plt.figure(figsize=(9, 3.5))
plt.step(np.arange(288), yy[:288, j], where='mid', label='actual (has data)', color='k', lw=0.8)
plt.plot(np.arange(288), pp[:288, j], label='GRU probability', color='tab:blue')
plt.axhline(0.7, color='g', ls='--', lw=0.8)
plt.axhline(0.3, color='r', ls='--', lw=0.8)
plt.xlabel('Test frame (10 min)'); plt.ylabel('p')
plt.title('Mote %d, load 0.5 - GRU prediction (dashed = bucket thresholds)' % motes[j])
plt.legend(loc='upper right'); plt.tight_layout()
plt.savefig('../results/ml/gru_prediction_example.png', dpi=150)

# ---------------- export for MATLAB ----------------
os.makedirs('../data/sim', exist_ok=True)
crit = pd.read_csv('../data/critical_flags.csv')
crit = crit.pivot(index='frame', columns='moteid', values='critical').values[n_train:T]
np.savetxt('../data/sim/crit.csv', crit, fmt='%d', delimiter=',')

n_te = T - n_train
for L in LOADS:
    k = lte == L
    np.savetxt('../data/sim/A_%d.csv' % L, yte[k].reshape(n_te, M), fmt='%d', delimiter=',')
    np.savetxt('../data/sim/P_gru_%d.csv' % L, p_gru[k].reshape(n_te, M), fmt='%.4f', delimiter=',')
    np.savetxt('../data/sim/P_rf_%d.csv' % L, p_rf[k].reshape(n_te, M), fmt='%.4f', delimiter=',')
    np.savetxt('../data/sim/P_pers_%d.csv' % L, p_pers[k].reshape(n_te, M), fmt='%.4f', delimiter=',')
print('\nsaved predictions in data/sim/')
