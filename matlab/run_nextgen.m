% main simulation of Next Gen BM-LoRa
% compares TDMA-LoRa, BM-LoRa (base paper), pure ALOHA and Next Gen BM-LoRa
% traffic and predictions come from the python part (data/sim folder)

clear; clc; close all;
tic;

out = '../results/nextgen/';
Nlist = 10:10:120;
loads = 1:9;                 % load 0.1 to 0.9

opt.th_low = 0.3;            % bucket thresholds
opt.th_high = 0.7;
opt.dynamic = true;

D.crit = csvread('../data/sim/crit.csv');
for L = loads
    D.A{L} = csvread(sprintf('../data/sim/A_%d.csv', L));
    D.P{L} = csvread(sprintf('../data/sim/P_gru_%d.csv', L));
end
fprintf('test frames: %d, motes: %d\n', size(D.crit, 1), size(D.crit, 2));

col.tdma = [0 0.45 0.74];   col.bm = [0.85 0.33 0.1];
col.aloha = [0.5 0.5 0.5];  col.ng = [0.13 0.6 0.2];

%% case 1 : energy vs N for load 0.2, 0.5, 0.8
prm = lora_params(12, 50);
protos = {'tdma', 'bm', 'aloha', 'nextgen'};
c1 = struct();
for L = [2 5 8]
    for i = 1:length(Nlist)
        R = run_point(Nlist(i), L, prm, D, protos, opt);
        for k = 1:length(protos)
            c1.(protos{k}).E(L, i) = R.(protos{k}).Etot;
            c1.(protos{k}).Eg(L, i) = R.(protos{k}).Eg;
            c1.(protos{k}).En(L, i) = R.(protos{k}).En;
            c1.(protos{k}).pdr(L, i) = R.(protos{k}).pdr;
            c1.(protos{k}).lat(L, i) = R.(protos{k}).lat;
            c1.(protos{k}).col(L, i) = R.(protos{k}).col;
            c1.(protos{k}).emax(L, i) = max(R.(protos{k}).Enode);
            c1.(protos{k}).aes(L, i) = R.(protos{k}).E_aes;
        end
        c1.nextgen.modes(L, i, :) = R.nextgen.modes;
    end
    fprintf('case 1 load %.1f done (%.0f s)\n', L/10, toc);
end

for L = [2 5 8]
    figure('visible', 'off');
    plot(Nlist, c1.tdma.E(L,:), '-o', 'Color', col.tdma, 'LineWidth', 1.5); hold on;
    plot(Nlist, c1.bm.E(L,:), '-s', 'Color', col.bm, 'LineWidth', 1.5);
    plot(Nlist, c1.aloha.E(L,:), '-^', 'Color', col.aloha, 'LineWidth', 1.5);
    plot(Nlist, c1.nextgen.E(L,:), '-d', 'Color', col.ng, 'LineWidth', 1.5);
    grid on;
    xlabel('N (Number of End Nodes)');
    ylabel('Total Energy Consumption (J)');
    title(sprintf('Total Energy vs N (traffic load = %.1f)', L/10));
    legend('TDMA-LoRa', 'BM-LoRa', 'Pure ALOHA', 'Next Gen BM-LoRa', 'Location', 'northwest');
    print(gcf, sprintf('%sng_fig1_total_energy_load0%d.png', out, L), '-dpng', '-r150');
end

L = 5;
figure('visible', 'off');
subplot(1,2,1);
plot(Nlist, c1.tdma.Eg(L,:), '-o', 'Color', col.tdma, 'LineWidth', 1.5); hold on;
plot(Nlist, c1.bm.Eg(L,:), '-s', 'Color', col.bm, 'LineWidth', 1.5);
plot(Nlist, c1.nextgen.Eg(L,:), '-d', 'Color', col.ng, 'LineWidth', 1.5);
grid on; xlabel('N'); ylabel('Gateway Energy (J)'); title('Gateway (load 0.5)');
legend('TDMA-LoRa', 'BM-LoRa', 'Next Gen', 'Location', 'northwest');
subplot(1,2,2);
plot(Nlist, c1.tdma.En(L,:), '-o', 'Color', col.tdma, 'LineWidth', 1.5); hold on;
plot(Nlist, c1.bm.En(L,:), '-s', 'Color', col.bm, 'LineWidth', 1.5);
plot(Nlist, c1.nextgen.En(L,:), '-d', 'Color', col.ng, 'LineWidth', 1.5);
grid on; xlabel('N'); ylabel('End Node Energy (J)'); title('End nodes (load 0.5)');
print(gcf, [out 'ng_fig2_gateway_endnode_load05.png'], '-dpng', '-r150');

%% load sweep at N = 120 (where base paper loses to TDMA)
N = 120;
protos2 = {'tdma', 'bm', 'nextgen', 'nextgen_static'};
sw = struct();
rho_all = [];  mode_all = [];
for L = loads
    R = run_point(N, L, prm, D, protos2, opt);
    for k = 1:length(protos2)
        sw.(protos2{k})(L) = R.(protos2{k}).Etot;
    end
    sw.modes(L, :) = R.nextgen.modes;
    sw.buckets(L, :) = R.nextgen.buckets;
    sw.fnr(L) = R.nextgen.fnr;
    sw.fpr(L) = R.nextgen.fpr;
    sw.p(L) = mean(D.A{L}(:));
    rho_all = [rho_all; R.nextgen.rho];
    mode_all = [mode_all; R.nextgen.mode];
end
fprintf('load sweep done (%.0f s)\n', toc);

figure('visible', 'off');
plot(loads/10, sw.tdma, '-o', 'Color', col.tdma, 'LineWidth', 1.5); hold on;
plot(loads/10, sw.bm, '-s', 'Color', col.bm, 'LineWidth', 1.5);
plot(loads/10, sw.nextgen, '-d', 'Color', col.ng, 'LineWidth', 1.5);
plot(loads/10, sw.nextgen_static, '--d', 'Color', col.ng, 'LineWidth', 1.2);
grid on;
xlabel('Traffic load p');
ylabel('Total Energy Consumption (J)');
title('Total Energy vs Traffic Load (N = 120)');
legend('TDMA-LoRa', 'BM-LoRa', 'Next Gen BM-LoRa', 'Next Gen (fixed c = 0.5)', 'Location', 'southeast');
print(gcf, [out 'ng_fig3_energy_vs_load_N120.png'], '-dpng', '-r150');

figure('visible', 'off');
bar(loads/10, 100*sw.modes, 'stacked');
xlabel('Traffic load p'); ylabel('Frames (%)');
title('Frame type chosen by the gateway (N = 120)');
legend('BM mode', 'Hybrid mode', 'TDMA mode', 'Location', 'southoutside', 'Orientation', 'horizontal');
ylim([0 100]); grid on;
print(gcf, [out 'ng_fig4_mode_share.png'], '-dpng', '-r150');

figure('visible', 'off');
bar(loads/10, 100*sw.buckets, 'stacked');
xlabel('Traffic load p'); ylabel('Normal nodes (%)');
title('Bucket of normal nodes in hybrid frames (N = 120)');
legend('Promoted', 'Contending', 'Excluded', 'Location', 'southoutside', 'Orientation', 'horizontal');
ylim([0 100]); grid on;
print(gcf, [out 'ng_fig4b_bucket_share.png'], '-dpng', '-r150');

figure('visible', 'off');
mk = {'o', 's', '^'};
cc = [col.ng; [0.9 0.6 0]; col.tdma];
for m = 1:3
    k = mode_all == m;
    plot(rho_all(k), m + 0.15*randn(sum(k), 1), mk{m}, 'Color', cc(m,:), 'MarkerSize', 3); hold on;
end
set(gca, 'YTick', 1:3, 'YTickLabel', {'BM', 'Hybrid', 'TDMA'});
xlabel('Predicted normal-node load  \rho = mean(p_i)');
ylabel('Mode chosen');
title('Mode selected by safety rule vs predicted load (N = 120)');
grid on; xlim([0 1]); ylim([0.4 3.6]);
print(gcf, [out 'ng_fig5_rho_vs_mode.png'], '-dpng', '-r150');

%% case 2 : spreading factor (load 0.5)
sflist = [12 10 7];
protos3 = {'tdma', 'bm', 'nextgen'};
c2 = struct();
for s = 1:3
    prm2 = lora_params(sflist(s), 50);
    for i = 1:length(Nlist)
        R = run_point(Nlist(i), 5, prm2, D, protos3, opt);
        for k = 1:3
            c2.(protos3{k})(s, i) = R.(protos3{k}).Etot;
        end
    end
end
fprintf('case 2 done (%.0f s)\n', toc);

figure('visible', 'off', 'Position', [100 100 900 480]);
ls = {'-', '--', ':'};
for s = 1:3
    plot(Nlist, c2.tdma(s,:), [ls{s} 'o'], 'Color', col.tdma, 'LineWidth', 1.3); hold on;
    plot(Nlist, c2.bm(s,:), [ls{s} 's'], 'Color', col.bm, 'LineWidth', 1.3);
    plot(Nlist, c2.nextgen(s,:), [ls{s} 'd'], 'Color', col.ng, 'LineWidth', 1.3);
end
grid on;
xlabel('N (Number of End Nodes)'); ylabel('Total Energy Consumption (J)');
title('Total Energy vs N for different SF (load 0.5)');
legend('TDMA SF12', 'BM-LoRa SF12', 'Next Gen SF12', 'TDMA SF10', 'BM-LoRa SF10', 'Next Gen SF10', ...
    'TDMA SF7', 'BM-LoRa SF7', 'Next Gen SF7', 'Location', 'eastoutside');
print(gcf, [out 'ng_fig6_case2_sf.png'], '-dpng', '-r150');

%% case 3 : payload (load 0.5)
plist = [50 80 100];
c3 = struct();
for s = 1:3
    prm3 = lora_params(12, plist(s));
    for i = 1:length(Nlist)
        R = run_point(Nlist(i), 5, prm3, D, protos3, opt);
        for k = 1:3
            c3.(protos3{k})(s, i) = R.(protos3{k}).Etot;
        end
    end
end
fprintf('case 3 done (%.0f s)\n', toc);

figure('visible', 'off', 'Position', [100 100 900 480]);
for s = 1:3
    plot(Nlist, c3.tdma(s,:), [ls{s} 'o'], 'Color', col.tdma, 'LineWidth', 1.3); hold on;
    plot(Nlist, c3.bm(s,:), [ls{s} 's'], 'Color', col.bm, 'LineWidth', 1.3);
    plot(Nlist, c3.nextgen(s,:), [ls{s} 'd'], 'Color', col.ng, 'LineWidth', 1.3);
end
grid on;
xlabel('N (Number of End Nodes)'); ylabel('Total Energy Consumption (J)');
title('Total Energy vs N for different payload (load 0.5)');
legend('TDMA 50B', 'BM-LoRa 50B', 'Next Gen 50B', 'TDMA 80B', 'BM-LoRa 80B', 'Next Gen 80B', ...
    'TDMA 100B', 'BM-LoRa 100B', 'Next Gen 100B', 'Location', 'eastoutside');
print(gcf, [out 'ng_fig7_case3_payload.png'], '-dpng', '-r150');

%% other metrics at load 0.5
L = 5;
figure('visible', 'off');
plot(Nlist, 100*c1.tdma.pdr(L,:), '-o', 'Color', col.tdma, 'LineWidth', 1.5); hold on;
plot(Nlist, 100*c1.bm.pdr(L,:), '-s', 'Color', col.bm, 'LineWidth', 1.5);
plot(Nlist, 100*c1.aloha.pdr(L,:), '-^', 'Color', col.aloha, 'LineWidth', 1.5);
plot(Nlist, 100*c1.nextgen.pdr(L,:), '-d', 'Color', col.ng, 'LineWidth', 1.5);
grid on; xlabel('N (Number of End Nodes)'); ylabel('Packet Delivery Ratio (%)');
title('PDR vs N (load 0.5)'); ylim([0 105]);
legend('TDMA-LoRa', 'BM-LoRa', 'Pure ALOHA', 'Next Gen BM-LoRa', 'Location', 'southwest');
print(gcf, [out 'ng_fig8_pdr.png'], '-dpng', '-r150');

figure('visible', 'off');
plot(Nlist, c1.tdma.lat(L,:), '-o', 'Color', col.tdma, 'LineWidth', 1.5); hold on;
plot(Nlist, c1.bm.lat(L,:), '-s', 'Color', col.bm, 'LineWidth', 1.5);
plot(Nlist, c1.aloha.lat(L,:), '-^', 'Color', col.aloha, 'LineWidth', 1.5);
plot(Nlist, c1.nextgen.lat(L,:), '-d', 'Color', col.ng, 'LineWidth', 1.5);
grid on; xlabel('N (Number of End Nodes)'); ylabel('Average latency of critical packets (s)');
title('Critical traffic latency vs N (load 0.5)');
legend('TDMA-LoRa', 'BM-LoRa', 'Pure ALOHA', 'Next Gen BM-LoRa', 'Location', 'northwest');
print(gcf, [out 'ng_fig9_critical_latency.png'], '-dpng', '-r150');

figure('visible', 'off');
plot(Nlist, 100*c1.aloha.col(2,:), '-^', 'Color', col.aloha, 'LineWidth', 1.5); hold on;
plot(Nlist, 100*c1.aloha.col(5,:), '--^', 'Color', col.aloha, 'LineWidth', 1.5);
plot(Nlist, 100*c1.aloha.col(8,:), ':^', 'Color', col.aloha, 'LineWidth', 1.5);
plot(Nlist, zeros(size(Nlist)), '-d', 'Color', col.ng, 'LineWidth', 1.5);
grid on; xlabel('N (Number of End Nodes)'); ylabel('Collision probability (%)');
title('Collision probability vs N');
legend('Pure ALOHA load 0.2', 'Pure ALOHA load 0.5', 'Pure ALOHA load 0.8', ...
    'TDMA / BM-LoRa / Next Gen (scheduled)', 'Location', 'northwest');
print(gcf, [out 'ng_fig10_collision.png'], '-dpng', '-r150');

% lifetime = time till the most loaded node runs out, shown relative to TDMA
life.bm = c1.tdma.emax(L,:) ./ c1.bm.emax(L,:);
life.aloha = c1.tdma.emax(L,:) ./ c1.aloha.emax(L,:);
life.ng = c1.tdma.emax(L,:) ./ c1.nextgen.emax(L,:);
figure('visible', 'off');
plot(Nlist, ones(size(Nlist)), '-o', 'Color', col.tdma, 'LineWidth', 1.5); hold on;
plot(Nlist, life.bm, '-s', 'Color', col.bm, 'LineWidth', 1.5);
plot(Nlist, life.aloha, '-^', 'Color', col.aloha, 'LineWidth', 1.5);
plot(Nlist, life.ng, '-d', 'Color', col.ng, 'LineWidth', 1.5);
grid on; xlabel('N (Number of End Nodes)'); ylabel('Network lifetime (relative to TDMA-LoRa)');
title('Network lifetime (first node death), load 0.5');
legend('TDMA-LoRa', 'BM-LoRa', 'Pure ALOHA', 'Next Gen BM-LoRa', 'Location', 'southeast'); ylim([0 2.2]);
print(gcf, [out 'ng_fig11_lifetime.png'], '-dpng', '-r150');

%% AES : AES-256 for critical nodes vs AES-128 for everyone
N = 120;  L = 5;
R1 = run_point(N, L, prm, D, {'nextgen'}, opt);
prm_128 = prm;
prm_128.E_aes256 = prm.E_aes128;
R2 = run_point(N, L, prm_128, D, {'nextgen'}, opt);
aes.with256 = R1.nextgen.Etot;
aes.all128 = R2.nextgen.Etot;
aes.share = 100*R1.nextgen.E_aes/R1.nextgen.Etot;
fprintf('\nAES (N=120, load 0.5): total %.4f J with AES-256 for critical, %.4f J with AES-128 only\n', aes.with256, aes.all128);
fprintf('extra energy for AES-256 = %.6f J (%.5f %%), AES share of total energy = %.4f %%\n', ...
    aes.with256 - aes.all128, 100*(aes.with256 - aes.all128)/aes.all128, aes.share);

figure('visible', 'off');
aes_mJ = 1000*[c1.tdma.aes(5,:); c1.bm.aes(5,:); c1.nextgen.aes(5,:)]';
plot(Nlist, aes_mJ(:,1), '-o', 'Color', col.tdma, 'LineWidth', 1.5); hold on;
plot(Nlist, aes_mJ(:,2), '-s', 'Color', col.bm, 'LineWidth', 1.5);
plot(Nlist, aes_mJ(:,3), '-d', 'Color', col.ng, 'LineWidth', 1.5);
grid on; xlabel('N (Number of End Nodes)'); ylabel('Encryption energy (mJ)');
title('AES encryption energy (load 0.5)');
legend('TDMA-LoRa (all AES-256)', 'BM-LoRa', 'Next Gen BM-LoRa', 'Location', 'northwest');
print(gcf, [out 'ng_fig12_aes_energy.png'], '-dpng', '-r150');

%% break-even prediction accuracy (extended energy model)
N = 120;
pl = 0.1:0.1:0.9;
Astar = zeros(size(pl));
gru_acc = zeros(size(pl));
for k = 1:length(pl)
    Astar(k) = breakeven(N, pl(k), prm);
    gru_acc(k) = mean(mean((D.P{k} > 0.5) == D.A{k}));
end
figure('visible', 'off');
plot(pl, Astar, '-o', 'Color', col.bm, 'LineWidth', 1.5); hold on;
plot(pl, gru_acc, '-d', 'Color', col.ng, 'LineWidth', 1.5);
grid on; xlabel('Traffic load p'); ylabel('Prediction accuracy');
title('Minimum accuracy needed vs GRU accuracy (N = 120)');
legend('Break-even accuracy A*', 'GRU accuracy (test)', 'Location', 'east');
ylim([0 1]);
print(gcf, [out 'ng_fig13_breakeven_accuracy.png'], '-dpng', '-r150');

figure('visible', 'off');
for p = [0.2 0.5 0.8]
    [a, Al, Eng, Ebm] = breakeven(N, p, prm);
    h = plot(Al, Eng, 'LineWidth', 1.5); hold on;
    plot([0 1], [Ebm Ebm], '--', 'Color', get(h, 'Color'), 'LineWidth', 1);
end
grid on; xlabel('Prediction accuracy A'); ylabel('Energy per cycle set (J)');
title('Next Gen energy vs prediction accuracy (dashed = BM-LoRa), N = 120');
legend('Next Gen p=0.2', 'BM-LoRa p=0.2', 'Next Gen p=0.5', 'BM-LoRa p=0.5', 'Next Gen p=0.8', 'BM-LoRa p=0.8', ...
    'Location', 'northeast');
print(gcf, [out 'ng_fig14_energy_vs_accuracy.png'], '-dpng', '-r150');

%% which predictor is used at the gateway (N = 120)
pred_names = {'pers', 'rf', 'gru'};
pe = zeros(2, 3);  pfn = zeros(2, 3);  pdl = zeros(2, 3);
row = 0;
for L = [5 8]
    row = row + 1;
    for k = 1:3
        D2 = D;
        D2.P{L} = csvread(sprintf('../data/sim/P_%s_%d.csv', pred_names{k}, L));
        R = run_point(120, L, prm, D2, {'nextgen'}, opt);
        pe(row, k) = R.nextgen.Etot;
        pfn(row, k) = R.nextgen.fnr;
        pdl(row, k) = R.nextgen.lat_all;
    end
end
figure('visible', 'off');
subplot(1,2,1);
bar(pe);
set(gca, 'XTickLabel', {'load 0.5', 'load 0.8'});
ylabel('Total Energy (J)'); title('Energy'); grid on; ylim([0 80]);
legend('Persistence', 'Random Forest', 'GRU', 'Location', 'northwest');
subplot(1,2,2);
bar(pdl);
set(gca, 'XTickLabel', {'load 0.5', 'load 0.8'});
ylabel('Average packet delay (s)'); title('Delay of all packets'); grid on;
print(gcf, [out 'ng_fig15_predictor_energy_delay.png'], '-dpng', '-r150');

%% print summary and save numbers
fprintf('\n===== RESULTS (SF 12, payload 50) =====\n');
for L = [2 5 8]
    fprintf('\nload %.1f  (actual p in test = %.3f)\n', L/10, mean(D.A{L}(:)));
    fprintf('  N   TDMA     BM     ALOHA   NextGen  | save vs TDMA  save vs BM\n');
    for i = [3 6 9 12]
        t = c1.tdma.E(L,i);  b = c1.bm.E(L,i);  n = c1.nextgen.E(L,i);
        fprintf('%4d %7.2f %7.2f %7.2f %7.2f  | %6.1f %%     %6.1f %%\n', Nlist(i), t, b, c1.aloha.E(L,i), n, ...
            100*(t-n)/t, 100*(b-n)/b);
    end
end

fprintf('\nload sweep, N = 120\n');
fprintf(' load  p_test   TDMA     BM    NextGen  NG(c=0.5)  BM%%  Hyb%%  TDMA%%   FPR    FNR\n');
for L = loads
    fprintf('  %.1f   %.3f  %6.2f  %6.2f  %6.2f   %6.2f   %4.0f  %4.0f  %4.0f   %.3f  %.3f\n', L/10, sw.p(L), ...
        sw.tdma(L), sw.bm(L), sw.nextgen(L), sw.nextgen_static(L), 100*sw.modes(L,:), sw.fpr(L), sw.fnr(L));
end
k = find(sw.bm > sw.tdma, 1);
if ~isempty(k)
    fprintf('BM-LoRa loses to TDMA from load %.1f\n', k/10);
end
fprintf('Next Gen above TDMA at any load: %d,  above BM at any load: %d\n', any(sw.nextgen > sw.tdma), any(sw.nextgen > sw.bm));
fprintf('Next Gen (c=0.5) above TDMA: %d, above BM: %d\n', any(sw.nextgen_static > sw.tdma), any(sw.nextgen_static > sw.bm));

fprintf('\nmode boundaries from data (rho):\n');
for m = 1:3
    r = rho_all(mode_all == m);
    if ~isempty(r)
        fprintf('  mode %d : rho from %.2f to %.2f (%d frames)\n', m, min(r), max(r), length(r));
    end
end

fprintf('\nother metrics, load 0.5\n');
fprintf('  N   PDR%%: TDMA  BM  ALOHA  NG  | latency(s): TDMA  BM  ALOHA  NG | life: BM  ALOHA  NG\n');
for i = [3 6 9 12]
    fprintf('%4d   %5.1f %5.1f %5.1f %5.1f | %6.1f %6.1f %6.1f %6.1f | %5.2f %5.2f %5.2f\n', Nlist(i), ...
        100*c1.tdma.pdr(5,i), 100*c1.bm.pdr(5,i), 100*c1.aloha.pdr(5,i), 100*c1.nextgen.pdr(5,i), ...
        c1.tdma.lat(5,i), c1.bm.lat(5,i), c1.aloha.lat(5,i), c1.nextgen.lat(5,i), ...
        life.bm(i), life.aloha(i), life.ng(i));
end

fprintf('\ncase 2 (load 0.5), N = 120\n');
for s = 1:3
    fprintf('  SF %2d : TDMA %.2f  BM %.2f  NextGen %.2f  (save vs BM %.1f %%)\n', sflist(s), ...
        c2.tdma(s,end), c2.bm(s,end), c2.nextgen(s,end), 100*(c2.bm(s,end)-c2.nextgen(s,end))/c2.bm(s,end));
end
fprintf('case 3 (load 0.5), N = 120\n');
for s = 1:3
    fprintf('  payload %3d : TDMA %.2f  BM %.2f  NextGen %.2f  (save vs BM %.1f %%)\n', plist(s), ...
        c3.tdma(s,end), c3.bm(s,end), c3.nextgen(s,end), 100*(c3.bm(s,end)-c3.nextgen(s,end))/c3.bm(s,end));
end

fprintf('\nbreak-even accuracy (N=120):\n');
for k = 1:length(pl)
    fprintf('  p = %.1f : A* = %.3f   GRU accuracy = %.3f\n', pl(k), Astar(k), gru_acc(k));
end

fprintf('\npredictor at gateway (N=120): [persistence  RF  GRU]\n');
fprintf('  load 0.5 : energy %.2f %.2f %.2f  FNR %.3f %.3f %.3f  delay %.1f %.1f %.1f s\n', pe(1,:), pfn(1,:), pdl(1,:));
fprintf('  load 0.8 : energy %.2f %.2f %.2f  FNR %.3f %.3f %.3f  delay %.1f %.1f %.1f s\n', pe(2,:), pfn(2,:), pdl(2,:));

fprintf('\nbuckets in hybrid frames (N=120): promoted / contending / excluded\n');
for L = loads
    fprintf('  load %.1f : %4.1f %%  %4.1f %%  %4.1f %%\n', L/10, 100*sw.buckets(L,:));
end

csvwrite([out 'case1_total_energy.csv'], [Nlist' c1.tdma.E([2 5 8],:)' c1.bm.E([2 5 8],:)' c1.aloha.E([2 5 8],:)' c1.nextgen.E([2 5 8],:)']);
csvwrite([out 'load_sweep_N120.csv'], [(loads/10)' sw.p' sw.tdma' sw.bm' sw.nextgen' sw.nextgen_static' sw.modes sw.fpr' sw.fnr']);
csvwrite([out 'metrics_load05.csv'], [Nlist' c1.tdma.pdr(5,:)' c1.bm.pdr(5,:)' c1.aloha.pdr(5,:)' c1.nextgen.pdr(5,:)' ...
    c1.tdma.lat(5,:)' c1.bm.lat(5,:)' c1.aloha.lat(5,:)' c1.nextgen.lat(5,:)' life.bm' life.aloha' life.ng']);
csvwrite([out 'breakeven.csv'], [pl' Astar' gru_acc']);
fprintf('\nall done in %.0f s, plots in %s\n', toc, out);
