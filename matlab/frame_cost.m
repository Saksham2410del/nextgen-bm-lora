function [eg, en, Tf, tdone, eg_s, en_s] = frame_cost(mode, crit, d, bucket, prm)
% energy of one frame for every node and for the gateway
%
% mode   0 = BM-LoRa (base paper), 1 = BM mode, 2 = hybrid mode,
%        3 = TDMA-LoRa (base paper), 4 = TDMA mode of next gen
% crit   1 if node is critical in this frame
% d      1 if node has data (can be a probability when we only estimate)
% bucket used only in hybrid mode: 1 promoted, 2 contending, 3 excluded
%
% tdone  time (from frame start) when packet of the node reaches gateway,
%        NaN if node did not send anything

Td = prm.Td;  Tg = prm.Tg;  Tcp = prm.Tcp;
slot = Td + Tg;

crit = logical(crit(:));
d = d(:);
N = length(d);

rx = zeros(N,1);  tx = zeros(N,1);  sb = zeros(N,1);
tdone = NaN(N,1);

if mode == 3
    % TDMA, every node has its own slot and sends in it
    Tf = Tcp + N*slot;
    rx(:) = Tcp;
    tx(:) = Td;
    sb(:) = N*Tg;
    tdone = Tcp + ((1:N)' - 1)*slot + Td;
    listen = N*slot;

elseif mode == 4
    % every node gets a slot (critical first), no CAP
    % node with nothing to send sleeps in its slot
    Tf = Tcp + N*slot;
    rx(:) = Tcp;
    tx = d*Td;
    tx(crit) = Td;
    listen = N*slot;
    order = [find(crit); find(~crit)];
    pos = zeros(N,1);
    pos(order) = 1:N;
    tdone = Tcp + (pos - 1)*slot + Td;
    tdone(tx == 0) = NaN;

elseif mode == 0 || mode == 1
    % critical slots, then CAP for all normal nodes, then requested slots
    c_idx = find(crit);
    n_idx = find(~crit);
    Nc = length(c_idx);
    Nn = length(n_idx);
    Tcap = Nn*prm.Tsub;
    Nn1 = sum(d(n_idx));

    if mode == 0
        rx(c_idx) = Tcp;      % in base paper only critical nodes receive CP
    else
        rx(:) = Tcp;          % in our protocol every node reads the bit-map
    end
    tx(c_idx) = Td;
    tx(n_idx) = d(n_idx)*(Tcap + Td);

    Tf = Tcp + Nc*slot + Tcap + Nn1*slot;
    listen = Nc*slot + Tcap + Nn1*slot;

    tdone(c_idx) = Tcp + ((1:Nc)' - 1)*slot + Td;
    has = n_idx(d(n_idx) == 1);
    tdone(has) = Tcp + Nc*slot + Tcap + ((1:length(has))' - 1)*slot + Td;

else
    % hybrid: critical slots, promoted slots, short CAP, contending slots
    c_idx = find(crit);
    p_idx = find(~crit & bucket(:) == 1);
    k_idx = find(~crit & bucket(:) == 2);
    Nc = length(c_idx);
    Np = length(p_idx);
    Nk = length(k_idx);
    Tcap = Nk*prm.Tsub;
    Nk1 = sum(d(k_idx));

    rx(:) = Tcp;
    tx(c_idx) = Td;
    tx(p_idx) = d(p_idx)*Td;
    tx(k_idx) = d(k_idx)*(Tcap + Td);
    % excluded nodes just sleep

    Tf = Tcp + (Nc + Np)*slot + Tcap + Nk1*slot;
    listen = (Nc + Np)*slot + Tcap + Nk1*slot;

    tdone(c_idx) = Tcp + ((1:Nc)' - 1)*slot + Td;
    j = find(d(p_idx) == 1);
    tdone(p_idx(j)) = Tcp + (Nc + j - 1)*slot + Td;
    has = k_idx(d(k_idx) == 1);
    tdone(has) = Tcp + (Nc + Np)*slot + Tcap + ((1:length(has))' - 1)*slot + Td;
end

sl = Tf - rx - tx - sb;
sl(sl < 0) = 0;
en = prm.Prxn*rx + prm.Ptxn*tx + prm.Psbn*sb + prm.Psn*sl;
eg = Tcp*prm.Ptxg + listen*prm.Prxg + (Tf - Tcp - listen)*prm.Psg;

% sleep period of the duty cycle
en_s = prm.Psn*Tf*ones(N,1);
eg_s = prm.Psg*Tf;
end
