import pandas as pd
import numpy as np

# Intel Berkeley Lab data (54 motes, reading every 31 s)
# http://db.csail.mit.edu/labdata/labdata.html

FRAME = '10min'
START = '2004-02-28 01:00'
END = '2004-03-10 01:00'
TRAIN_PART = 0.7
LOADS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]

cols = ['date', 'time', 'epoch', 'moteid', 'temperature', 'humidity', 'light', 'voltage']
df = pd.read_csv('../data/data.txt.gz', sep=r'\s+', header=None, names=cols)
print('raw rows:', len(df))

df = df.dropna()
df['ts'] = pd.to_datetime(df['date'] + ' ' + df['time'], format='mixed')
df = df[(df['moteid'] >= 1) & (df['moteid'] <= 54)]
df = df[(df['ts'] >= START) & (df['ts'] < END)]
df = df.drop_duplicates(subset=['moteid', 'ts'])
df['moteid'] = df['moteid'].astype(int)
print('rows after cleaning:', len(df))

# one value per mote per frame (mean of readings in that frame)
df['frame_time'] = df['ts'].dt.floor(FRAME)
frames = pd.date_range(START, END, freq=FRAME, inclusive='left')

sensors = ['temperature', 'humidity', 'light', 'voltage']
table = {}
keep = []
for m, g in df.groupby('moteid'):
    x = g.groupby('frame_time')[sensors].mean().reindex(frames)
    cover = x['temperature'].notna().mean()
    if cover < 0.8:
        print('dropping mote', m, 'coverage', round(cover, 2))
        continue
    # small gaps - just keep the last reading
    x = x.ffill().bfill()
    table[m] = x
    keep.append(m)

print('motes kept:', len(keep))
T = len(frames)
n_train = int(TRAIN_PART * T)
print('frames:', T, ' train:', n_train, ' test:', T - n_train)

# change from previous frame
rows = []
for m in keep:
    x = table[m].copy()
    x['dT'] = x['temperature'].diff().fillna(0)
    x['dH'] = x['humidity'].diff().fillna(0)
    x['dL'] = x['light'].diff().fillna(0)
    x['moteid'] = m
    x['frame'] = np.arange(T)
    x['hour'] = frames.hour + frames.minute / 60
    rows.append(x)
data = pd.concat(rows, ignore_index=True)

# activity score: biggest change among temp, humidity and light
# each change is divided by its 90th percentile (from train part) so all are on same scale
train = data[data['frame'] < n_train]
scale = {}
for c in ['dT', 'dH', 'dL']:
    scale[c] = np.percentile(np.abs(train[c]), 90)
    if scale[c] == 0:
        scale[c] = 1
print('scale:', {k: round(v, 3) for k, v in scale.items()})

data['score'] = np.maximum.reduce([np.abs(data['dT']) / scale['dT'],
                                   np.abs(data['dH']) / scale['dH'],
                                   np.abs(data['dL']) / scale['dL']])

# send on change: node has data when score is above a threshold
# threshold picked from train part so that on average p fraction of frames have data
train_score = data.loc[data['frame'] < n_train, 'score']
thr = {}
for p in LOADS:
    thr[p] = np.quantile(train_score, 1 - p)
    data['A_' + str(int(p * 10))] = (data['score'] > thr[p]).astype(int)

print('\nload   threshold   actual p (train)   actual p (test)')
for p in LOADS:
    a = data['A_' + str(int(p * 10))]
    print(f'{p:.1f}   {thr[p]:9.3f}   {a[data.frame < n_train].mean():.3f}             {a[data.frame >= n_train].mean():.3f}')

data.to_csv('../data/frames.csv', index=False)
pd.Series(keep).to_csv('../data/motes.csv', index=False, header=['moteid'])
with open('../data/split.txt', 'w') as f:
    f.write(f'{T} {n_train}\n')
print('\nsaved data/frames.csv')
