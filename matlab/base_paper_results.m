% reproduce the results of the base paper (Fig 5 to Fig 13)
% case 1 - probability, case 2 - SF, case 3 - payload

clear; clc; close all;

outdir = '../results/base_paper/';
N = 10:10:120;
c = 0.5;

%% case 1 : variation in probability p
prm = lora_params(12, 50);
plist = [0.2 0.5 0.8];

Eg_t = zeros(size(N));  En_t = zeros(size(N));
Eg_b = zeros(3, length(N));  En_b = zeros(3, length(N));

for i = 1:length(N)
    [Eg_t(i), En_t(i)] = tdma_energy(N(i), prm);
    for k = 1:3
        [Eg_b(k,i), En_b(k,i)] = bm_energy(N(i), plist(k), c, prm);
    end
end

names = {'Gateway', 'End Node', 'Total'};
for f = 1:3
    figure('visible', 'off');
    if f == 1
        yt = Eg_t;  yb = Eg_b;
    elseif f == 2
        yt = En_t;  yb = En_b;
    else
        yt = Eg_t + En_t;  yb = Eg_b + En_b;
    end
    plot(N, yt, '-o', 'LineWidth', 1.5); hold on;
    plot(N, yb(1,:), '-s', 'LineWidth', 1.5);
    plot(N, yb(2,:), '-s', 'LineWidth', 1.5);
    plot(N, yb(3,:), '-s', 'LineWidth', 1.5);
    grid on;
    xlabel('N (Number of End Nodes)');
    ylabel([names{f} ' Energy Consumption (J)']);
    title([names{f} ' Energy Consumption vs N']);
    legend('TDMA-LoRa', 'BM-LoRa (p=0.2)', 'BM-LoRa (p=0.5)', 'BM-LoRa (p=0.8)', 'Location', 'northwest');
    print(gcf, [outdir 'fig' num2str(4+f) '_case1_' strrep(lower(names{f}), ' ', '') '.png'], '-dpng', '-r150');
end

fprintf('\nCase 1 (SF=12, payload=50)\n');
fprintf('  N   TDMA   BM p=.2  BM p=.5  BM p=.8\n');
for i = 1:length(N)
    fprintf('%4d %7.2f %8.2f %8.2f %8.2f\n', N(i), Eg_t(i)+En_t(i), ...
        Eg_b(1,i)+En_b(1,i), Eg_b(2,i)+En_b(2,i), Eg_b(3,i)+En_b(3,i));
end
tot_t = Eg_t(end) + En_t(end);
for k = 1:3
    tot_b = Eg_b(k,end) + En_b(k,end);
    fprintf('saving at N=120, p=%.1f : %.1f %%\n', plist(k), 100*(tot_t - tot_b)/tot_t);
end

% where does TDMA start to win
for k = 1:3
    tot_b = Eg_b(k,:) + En_b(k,:);
    idx = find(tot_b > Eg_t + En_t, 1);
    if isempty(idx)
        fprintf('p=%.1f : BM-LoRa better for all N\n', plist(k));
    else
        fprintf('p=%.1f : TDMA better from N=%d\n', plist(k), N(idx));
    end
end

save_case = [N' Eg_t' En_t' Eg_b' En_b'];
csvwrite([outdir 'case1_values.csv'], save_case);

%% case 2 : variation in SF
sflist = [12 10 7];
Eg_t2 = zeros(3, length(N));  En_t2 = zeros(3, length(N));
Eg_b2 = zeros(3, length(N));  En_b2 = zeros(3, length(N));

for k = 1:3
    prm = lora_params(sflist(k), 50);
    for i = 1:length(N)
        [Eg_t2(k,i), En_t2(k,i)] = tdma_energy(N(i), prm);
        [Eg_b2(k,i), En_b2(k,i)] = bm_energy(N(i), 0.5, c, prm);
    end
end

for f = 1:3
    figure('visible', 'off');
    if f == 1
        yt = Eg_t2;  yb = Eg_b2;
    elseif f == 2
        yt = En_t2;  yb = En_b2;
    else
        yt = Eg_t2 + En_t2;  yb = Eg_b2 + En_b2;
    end
    for k = 1:3
        plot(N, yt(k,:), '-o', 'LineWidth', 1.5); hold on;
    end
    for k = 1:3
        plot(N, yb(k,:), '-s', 'LineWidth', 1.5);
    end
    grid on;
    xlabel('N (Number of End Nodes)');
    ylabel([names{f} ' Energy Consumption (J)']);
    title([names{f} ' Energy Consumption vs N (SF variation)']);
    legend('TDMA-LoRa (SF=12)', 'TDMA-LoRa (SF=10)', 'TDMA-LoRa (SF=7)', ...
        'BM-LoRa (SF=12)', 'BM-LoRa (SF=10)', 'BM-LoRa (SF=7)', 'Location', 'northwest');
    print(gcf, [outdir 'fig' num2str(7+f) '_case2_' strrep(lower(names{f}), ' ', '') '.png'], '-dpng', '-r150');
end

fprintf('\nCase 2 (p=0.5, payload=50), total at N=120\n');
for k = 1:3
    a = Eg_t2(k,end) + En_t2(k,end);
    b = Eg_b2(k,end) + En_b2(k,end);
    fprintf('SF=%2d : TDMA %.2f  BM %.2f  saving %.1f %%\n', sflist(k), a, b, 100*(a-b)/a);
end

%% case 3 : variation in payload
plen = [50 80 100];
Eg_t3 = zeros(3, length(N));  En_t3 = zeros(3, length(N));
Eg_b3 = zeros(3, length(N));  En_b3 = zeros(3, length(N));

for k = 1:3
    prm = lora_params(12, plen(k));
    for i = 1:length(N)
        [Eg_t3(k,i), En_t3(k,i)] = tdma_energy(N(i), prm);
        [Eg_b3(k,i), En_b3(k,i)] = bm_energy(N(i), 0.5, c, prm);
    end
end

for f = 1:3
    figure('visible', 'off');
    if f == 1
        yt = Eg_t3;  yb = Eg_b3;
    elseif f == 2
        yt = En_t3;  yb = En_b3;
    else
        yt = Eg_t3 + En_t3;  yb = Eg_b3 + En_b3;
    end
    for k = 1:3
        plot(N, yt(k,:), '-o', 'LineWidth', 1.5); hold on;
    end
    for k = 1:3
        plot(N, yb(k,:), '-s', 'LineWidth', 1.5);
    end
    grid on;
    xlabel('N (Number of End Nodes)');
    ylabel([names{f} ' Energy Consumption (J)']);
    title([names{f} ' Energy Consumption vs N (Payload variation)']);
    legend('TDMA-LoRa (Payload=50)', 'TDMA-LoRa (Payload=80)', 'TDMA-LoRa (Payload=100)', ...
        'BM-LoRa (Payload=50)', 'BM-LoRa (Payload=80)', 'BM-LoRa (Payload=100)', 'Location', 'northwest');
    print(gcf, [outdir 'fig' num2str(10+f) '_case3_' strrep(lower(names{f}), ' ', '') '.png'], '-dpng', '-r150');
end

fprintf('\nCase 3 (p=0.5, SF=12), total at N=120\n');
for k = 1:3
    a = Eg_t3(k,end) + En_t3(k,end);
    b = Eg_b3(k,end) + En_b3(k,end);
    fprintf('payload=%3d : TDMA %.2f  BM %.2f  saving %.1f %%\n', plen(k), a, b, 100*(a-b)/a);
end

fprintf('\nplots saved in %s\n', outdir);
