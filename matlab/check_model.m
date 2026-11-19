% check that the frame simulator gives the same energy as the
% equations of the base paper when traffic is random with probability p

clear; clc;
rng(1);

prm = lora_params(12, 50);
T = 400;
opt.th_low = 0.3;  opt.th_high = 0.7;  opt.dynamic = false;

fprintf('   N    p   TDMA eq   TDMA sim   BM eq    BM sim\n');
for N = [20 60 120]
    for p = [0.2 0.5 0.8]
        crit = false(N,1);
        crit(1:N/2) = true;
        opt.static_crit = crit;

        A = rand(T, N) < p;
        A(:, crit) = 0;
        An = zeros(T, N);

        r1 = simulate('tdma', A, An, [], prm, opt);
        r2 = simulate('bm', A, An, [], prm, opt);
        [g1, e1] = tdma_energy(N, prm);
        [g2, e2] = bm_energy(N, p, 0.5, prm);
        fprintf('%4d  %.1f  %8.2f  %8.2f  %8.2f  %8.2f\n', N, p, g1+e1, r1.Etot, g2+e2, r2.Etot);
    end
end
