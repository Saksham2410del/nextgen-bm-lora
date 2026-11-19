function X = expand_nodes(Y, N, seed)
% Y is (frames x motes). we need N nodes.
% first nodes are the real motes, extra nodes are real motes with a random time shift

[T, M] = size(Y);
rng(seed);
off = zeros(1, N);
if N > M
    off(M+1:N) = randi([1 T-1], 1, N-M);
end

X = zeros(T, N);
for i = 1:N
    m = mod(i-1, M) + 1;
    idx = mod((0:T-1) + off(i), T) + 1;
    X(:, i) = Y(idx, m);
end
end
