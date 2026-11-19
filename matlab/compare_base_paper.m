% same plots as Fig 5, 6 and 7 of the base paper (gateway, end node, total)
% but with our protocol added, all on the same Intel Lab traffic

clear; clc; close all;

out = '../results/nextgen/';
Nlist = 10:10:120;
opt.th_low = 0.3;
opt.th_high = 0.7;
opt.dynamic = true;

D.crit = csvread('../data/sim/crit.csv');
for L = [2 5 8]
    D.A{L} = csvread(sprintf('../data/sim/A_%d.csv', L));
    D.P{L} = csvread(sprintf('../data/sim/P_gru_%d.csv', L));
end

prm = lora_params(12, 50);
Eg = struct();  En = struct();
k = 0;
for L = [2 5 8]
    k = k + 1;
    for i = 1:length(Nlist)
        R = run_point(Nlist(i), L, prm, D, {'tdma', 'bm', 'nextgen'}, opt);
        Eg.tdma(k,i) = R.tdma.Eg;  En.tdma(k,i) = R.tdma.En;
        Eg.bm(k,i) = R.bm.Eg;      En.bm(k,i) = R.bm.En;
        Eg.ng(k,i) = R.nextgen.Eg; En.ng(k,i) = R.nextgen.En;
    end
end

names = {'Gateway', 'End Node', 'Total'};
files = {'cmp_fig5_gateway', 'cmp_fig6_endnode', 'cmp_fig7_total'};
bmc = [0.85 0.33 0.1];
ngc = [0.13 0.6 0.2];
ls = {'-', '--', ':'};
for f = 1:3
    if f == 1
        t = Eg.tdma;  b = Eg.bm;  n = Eg.ng;
    elseif f == 2
        t = En.tdma;  b = En.bm;  n = En.ng;
    else
        t = Eg.tdma + En.tdma;  b = Eg.bm + En.bm;  n = Eg.ng + En.ng;
    end
    figure('visible', 'off');
    plot(Nlist, t(1,:), '-o', 'Color', [0 0.45 0.74], 'LineWidth', 1.5); hold on;
    for k = 1:3
        plot(Nlist, b(k,:), [ls{k} 's'], 'Color', bmc, 'LineWidth', 1.3);
    end
    for k = 1:3
        plot(Nlist, n(k,:), [ls{k} 'd'], 'Color', ngc, 'LineWidth', 1.3);
    end
    grid on;
    xlabel('N (Number of End Nodes)');
    ylabel([names{f} ' Energy Consumption (J)']);
    title([names{f} ' Energy Consumption vs N']);
    legend('TDMA-LoRa', 'BM-LoRa (p=0.2)', 'BM-LoRa (p=0.5)', 'BM-LoRa (p=0.8)', ...
        'Next Gen (p=0.2)', 'Next Gen (p=0.5)', 'Next Gen (p=0.8)', 'Location', 'northwest');
    print(gcf, [out files{f} '.png'], '-dpng', '-r150');
end

fprintf('N=120     TDMA    BM .2   BM .5   BM .8   NG .2   NG .5   NG .8\n');
fprintf('gateway  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f\n', Eg.tdma(1,end), Eg.bm(:,end), Eg.ng(:,end));
fprintf('end node %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f  %6.2f\n', En.tdma(1,end), En.bm(:,end), En.ng(:,end));
