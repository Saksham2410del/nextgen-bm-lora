% test cases for the energy model and the frame simulator
% every test prints the expected and the obtained value

clear; clc;
st = {'FAIL', 'PASS'};
npass = 0;  ntest = 0;
prm = lora_params(12, 50);

% TC1 timing for SF 12, 50 bytes (hand calculation from eq 1 to 4)
ok = abs(prm.Tsym - 0.032768) < 1e-6 && abs(prm.Rdata - 183.105) < 0.01 ...
     && abs(prm.Td - 3.0092) < 1e-3 && abs(prm.Tcp - 0.4369) < 1e-3;
fprintf('TC1   Tsym = %.6f s, Rdata = %.3f bit/s, Td = %.4f s, Tcp = %.4f s   %s\n', ...
        prm.Tsym, prm.Rdata, prm.Td, prm.Tcp, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC2 TDMA total energy at N = 120 (paper Fig 7 gives about 77.2 J)
[g, e] = tdma_energy(120, prm);
Etdma = g + e;
ok = abs(Etdma - 77.2)/77.2 < 0.05;
fprintf('TC2   TDMA total energy N = 120: %.2f J (paper 77.2 J, error %.2f %%)   %s\n', ...
        Etdma, 100*abs(Etdma - 77.2)/77.2, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC3 and TC4 BM-LoRa vs TDMA at N = 120
[g, e] = bm_energy(120, 0.8, 0.5, prm);
Ebm8 = g + e;
ok = Ebm8 > Etdma;
fprintf('TC3   BM-LoRa p = 0.8: %.2f J, TDMA: %.2f J (BM-LoRa should be higher)   %s\n', Ebm8, Etdma, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

[g, e] = bm_energy(120, 0.2, 0.5, prm);
Ebm2 = g + e;
ok = Ebm2 < Etdma;
fprintf('TC4   BM-LoRa p = 0.2: %.2f J, TDMA: %.2f J (BM-LoRa should be lower)   %s\n', Ebm2, Etdma, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC5 and TC6 frame simulator vs equations, N = 60, p = 0.5
rng(3);
N = 60;  p = 0.5;
opt.th_low = 0.3;  opt.th_high = 0.7;  opt.dynamic = false;
crit = false(N,1);  crit(1:N/2) = true;
opt.static_crit = crit;
A = rand(400, N) < p;
A(:, crit) = 0;
An = zeros(400, N);
r1 = simulate('tdma', A, An, [], prm, opt);
r2 = simulate('bm', A, An, [], prm, opt);
[g1, e1] = tdma_energy(N, prm);
[g2, e2] = bm_energy(N, p, 0.5, prm);
d1 = 100*abs(r1.Etot - (g1 + e1))/(g1 + e1);
d2 = 100*abs(r2.Etot - (g2 + e2))/(g2 + e2);
ok = d1 < 1;
fprintf('TC5   TDMA N = 60: equation %.2f J, simulator %.2f J (difference %.2f %%)   %s\n', g1 + e1, r1.Etot, d1, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;
ok = d2 < 1;
fprintf('TC6   BM-LoRa N = 60, p = 0.5: equation %.2f J, simulator %.2f J (difference %.2f %%)   %s\n', g2 + e2, r2.Etot, d2, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC7 hybrid frame with every normal node contending must be the BM frame
rng(4);
N = 20;
crit = false(N,1);  crit(1:5) = true;
d = double(rand(N,1) < 0.5);  d(crit) = 1;
[ga, ea, Ta] = frame_cost(1, crit, d, [], prm);
[gb, eb, Tb] = frame_cost(2, crit, d, 2*ones(N,1), prm);
ok = abs(ga - gb) < 1e-12 && abs(sum(ea) - sum(eb)) < 1e-12 && abs(Ta - Tb) < 1e-12;
fprintf('TC7   all contending: BM frame %.4f J / %.2f s, hybrid frame %.4f J / %.2f s   %s\n', ...
        ga + sum(ea), Ta, gb + sum(eb), Tb, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC8 hybrid frame with every normal node promoted (all with data) has no CAP
d = ones(N,1);
[gc, ec, Tc] = frame_cost(2, crit, d, ones(N,1), prm);
Tt = prm.Tcp + N*(prm.Td + prm.Tg);
ok = abs(Tc - Tt) < 1e-9;
fprintf('TC8   all promoted: frame length %.2f s, Tcp + N(Td + Tg) = %.2f s   %s\n', Tc, Tt, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC9 a critical node gets the first slot of the hybrid frame
crit = false(N,1);  crit(7) = true;
d = double(rand(N,1) < 0.5);  d(7) = 1;
bucket = 2*ones(N,1);  bucket(1:3) = 1;
[gd, ed, Td_, tdone] = frame_cost(2, crit, d, bucket, prm);
ok = abs(tdone(7) - (prm.Tcp + prm.Td)) < 1e-9 && tdone(7) == min(tdone);
fprintf('TC9   critical node delivered at %.4f s, expected Tcp + Td = %.4f s   %s\n', tdone(7), prm.Tcp + prm.Td, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC10 virtual nodes for N > 51 are time shifted copies of real motes
Y = csvread('../data/sim/A_5.csv');
X = expand_nodes(Y, 120, 7);
m = mod((52:120) - 1, size(Y,2)) + 1;
ok = isequal(size(X), [size(Y,1) 120]) && isequal(X(:,1:51), Y) && isequal(sum(X(:,52:120)), sum(Y(:,m)));
fprintf('TC10  expand_nodes: size %d x %d, first 51 columns same as data, packets per shifted node kept   %s\n', ...
        size(X,1), size(X,2), st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC11 a wrongly excluded node is not lost, it is sent in the next frame
N = 10;
A = zeros(2, N);  A(1, 10) = 1;
An = zeros(2, N);
P = 0.5*ones(2, N);  P(:, 10) = 0.1;
opt.static_crit = false(N,1);
r = simulate('nextgen', A, An, P, prm, opt);
ok = r.pdr == 1 && r.mode(1) == 2 && r.lat_all > r.Trep;
fprintf('TC11  excluded node with data: frame 1 type %d (2 = hybrid), PDR %.2f, delay %.1f s > Trep %.1f s   %s\n', ...
        r.mode(1), r.pdr, r.lat_all, r.Trep, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

% TC12 an unusual reading makes a packet even if the reading did not change
A = zeros(3, N);
An = zeros(3, N);  An(1, 3) = 1;
P = 0.1*ones(3, N);
ra = simulate('tdma', A, An, [], prm, opt);
rb = simulate('nextgen', A, An, P, prm, opt);
ok = ra.pdr == 1 && rb.pdr == 1;
fprintf('TC12  unusual reading only: PDR TDMA %.2f, PDR Next Gen %.2f   %s\n', ra.pdr, rb.pdr, st{ok+1});
npass = npass + ok;  ntest = ntest + 1;

fprintf('\n%d of %d test cases passed\n', npass, ntest);
