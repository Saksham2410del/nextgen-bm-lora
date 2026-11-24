# checks on the files made by the python scripts
import time
import numpy as np
import pandas as pd
import torch
import torch.nn as nn

npass = 0
ntest = 0


def show(tc, text, ok):
    global npass, ntest
    ntest += 1
    npass += int(ok)
    print('%-5s %s   %s' % (tc, text, 'PASS' if ok else 'FAIL'))


s = open('../data/split.txt').read().split()
n_all, n_tr = int(s[0]), int(s[1])
fr = pd.read_csv('../data/frames.csv')
tr = fr[fr.frame < n_tr]
te = fr[fr.frame >= n_tr]

# TC13 share of train frames with data should be equal to the load
sh_tr = [tr['A_%d' % L].mean() for L in range(1, 10)]
err = max(abs(sh_tr[L - 1] - L / 10) for L in range(1, 10))
show('TC13', 'train share of frames with data for load 0.1..0.9: %s (max error %.4f)'
     % (' '.join('%.3f' % x for x in sh_tr), err), err < 0.005)

# TC14 share in test frames should go up with the load
sh_te = [te['A_%d' % L].mean() for L in range(1, 10)]
ok = all(sh_te[i] < sh_te[i + 1] for i in range(8))
show('TC14', 'test share of frames with data: %s' % ' '.join('%.3f' % x for x in sh_te), ok)

# TC15 isolation forest flags about 1 % of train readings (contamination = 0.01)
cf = pd.read_csv('../data/critical_flags.csv')
f_tr = cf[cf.frame < n_tr].critical.mean() * 100
f_te = cf[cf.frame >= n_tr].critical.mean() * 100
show('TC15', 'readings flagged critical: train %.2f %%, test %.2f %%' % (f_tr, f_te), abs(f_tr - 1) < 0.2)

# TC16 train / test split and size of files used by matlab
A5 = np.loadtxt('../data/sim/A_5.csv', delimiter=',')
C = np.loadtxt('../data/sim/crit.csv', delimiter=',')
ok = n_tr == int(0.7 * n_all) and A5.shape == (n_all - n_tr, 51) and C.shape == A5.shape
show('TC16', 'frames %d = %d train + %d test, A_5.csv %d x %d, crit.csv %d x %d'
     % (n_all, n_tr, n_all - n_tr, A5.shape[0], A5.shape[1], C.shape[0], C.shape[1]), ok)

# TC17 GRU outputs are probabilities for every test frame and node
mn, mx, bad = 1.0, 0.0, 0
for L in range(1, 10):
    P = np.loadtxt('../data/sim/P_gru_%d.csv' % L, delimiter=',')
    bad += np.isnan(P).sum() + int(P.shape != A5.shape)
    mn, mx = min(mn, P.min()), max(mx, P.max())
show('TC17', 'P_gru files: min %.4f, max %.4f, NaN or wrong size: %d' % (mn, mx, bad), bad == 0 and mn >= 0 and mx <= 1)


# TC18 saved GRU has 2 x 64 units: 13440 + 24960 + 65 = 38465 parameters
class GRUNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.gru = nn.GRU(input_size=4, hidden_size=64, num_layers=2, batch_first=True)
        self.fc = nn.Linear(64, 1)

    def forward(self, x):
        out, h = self.gru(x)
        return self.fc(out[:, -1, :]).squeeze(1)


state = torch.load('../results/ml/gru_model.pt')
npar = sum(v.numel() for v in state.values())
show('TC18', 'parameters in gru_model.pt: %d' % npar, npar == 38465)

# TC19 time taken by the GRU to predict one frame for 120 nodes
model = GRUNet()
model.load_state_dict(state)
model.eval()
x = torch.rand(120, 12, 4)
with torch.no_grad():
    model(x)
    t0 = time.time()
    for i in range(100):
        p = torch.sigmoid(model(x))
    ms = (time.time() - t0) / 100 * 1000
show('TC19', 'GRU prediction for 120 nodes takes %.2f ms (frame interval is 10 min)' % ms, ms < 1000)

print('\n%d of %d test cases passed' % (npass, ntest))
