function R = run_point(N, L, prm, D, protos, opt)
% runs the given protocols for N nodes at traffic load L
% D.A{L}, D.P{L} and D.crit come from the python part

A = expand_nodes(D.A{L}, N, 7);
P = expand_nodes(D.P{L}, N, 7);
C = expand_nodes(D.crit, N, 7);

% fixed critical nodes for BM-LoRa (c = 0.5 like base paper)
rng(11);
sc = false(N,1);
sc(randperm(N, round(N/2))) = true;
opt.static_crit = sc;

for k = 1:length(protos)
    name = protos{k};
    o = opt;
    pr = name;
    if strcmp(name, 'nextgen')
        o.dynamic = true;
    elseif strcmp(name, 'nextgen_static')
        o.dynamic = false;
        pr = 'nextgen';
    end
    rng(5);
    R.(name) = simulate(pr, A, C, P, prm, o);
end
end
