function r = simulate(proto, A, An, P, prm, opt)
% frame by frame simulation of one protocol
%
% proto  'tdma', 'bm', 'aloha' or 'nextgen'
% A      T x N matrix, 1 if node has new data in that frame
% An     T x N matrix, 1 if the reading of that frame is unusual
% P      T x N matrix, predicted probability of data (only for nextgen)
% opt    static_crit, dynamic, th_low, th_high

[T, N] = size(A);
Trep = prm.Tcp + N*(prm.Td + prm.Tg);   % same reporting period for every protocol
nblk = ceil(prm.payload/16);           % AES blocks in one payload

Eg = 0;  En = 0;  Eg_s = 0;  En_s = 0;  E_aes = 0;
Enode = zeros(N,1);
gen = 0;  got = 0;
ntx = 0;  ncol = 0;
lat = [];
modes = zeros(1,3);
rho_log = NaN(T,1);
mode_log = zeros(T,1);
lat_all = [];
bk = zeros(1,3);
n_hyb = 0;
fp = 0;  fn = 0;  n_one = 0;  n_zero = 0;

pend = zeros(N,1);        % packets still waiting from older frames
pend_ev = false(N,1);     % waiting packet has an unusual reading
wait_fr = zeros(N,1);
excl_last = false(N,1);
seen_anom = false(N,1);   % gateway got an unusual reading in last frame

for t = 1:T
    newd = A(t,:)' == 1 | An(t,:)' == 1;
    ev = An(t,:)' == 1;
    gen = gen + sum(newd);
    data = newd | pend > 0;
    aes = zeros(N,1);

    if strcmp(proto, 'tdma')
        crit = true(N,1);
        [eg, en, Tf, tdone, egs, ens] = frame_cost(3, crit, ones(N,1), [], prm);
        aes(:) = nblk*prm.E_aes256;          % scenario 1, every node uses AES-256

    elseif strcmp(proto, 'bm')
        crit = opt.static_crit(:);
        d = double(data);
        d(crit) = 1;
        [eg, en, Tf, tdone, egs, ens] = frame_cost(0, crit, d, [], prm);
        aes(crit) = nblk*prm.E_aes256;
        aes(~crit & ~isnan(tdone)) = nblk*prm.E_aes128;

    elseif strcmp(proto, 'aloha')
        % pure ALOHA, node sends at a random time, no retransmission
        idx = find(data);
        st = rand(length(idx),1)*(Trep - prm.Td);
        ok = true(length(idx),1);
        if length(idx) > 1
            [ss, ord] = sort(st);
            gap = diff(ss);
            col = false(length(idx),1);
            col(1:end-1) = gap < prm.Td;
            col(2:end) = col(2:end) | gap < prm.Td;
            ok(ord(col)) = false;
        end
        tx = zeros(N,1);
        tx(idx) = prm.Td;
        en = prm.Ptxn*tx + prm.Psn*(Trep - tx);
        eg = prm.Prxg*Trep;
        ens = prm.Psn*Trep*ones(N,1);
        egs = prm.Psg*Trep;
        tdone = NaN(N,1);
        tdone(idx(ok)) = st(ok) + prm.Td;
        ntx = ntx + length(idx);
        ncol = ncol + sum(~ok);
        aes(idx) = nblk*prm.E_aes128;

    else
        % next gen BM-LoRa
        if opt.dynamic
            crit = seen_anom;
        else
            crit = opt.static_crit(:);
        end
        ph = P(t,:)';

        bucket = 2*ones(N,1);
        bucket(ph > opt.th_high) = 1;
        bucket(ph < opt.th_low) = 3;
        bucket(excl_last & bucket == 3) = 2;   % missed last time, give a CAP subslot now

        % estimate energy of the three frame types with predicted values
        dest = ph;
        dest(crit) = 1;
        [g1, e1] = frame_cost(1, crit, dest, [], prm);
        [g2, e2] = frame_cost(2, crit, dest, bucket, prm);
        [g3, e3] = frame_cost(4, crit, dest, [], prm);
        % a missed node will join the CAP of next frame
        cap_len = sum(~crit & bucket == 2)*prm.Tsub;
        pen = sum(ph(~crit & bucket == 3))*prm.Ptxn*(cap_len + prm.Tsub);
        cost = [g1 + sum(e1), g2 + sum(e2) + pen, g3 + sum(e3)];
        [tmp, mode] = min(cost);
        modes(mode) = modes(mode) + 1;
        if any(~crit)
            rho_log(t) = mean(ph(~crit));
        end
        mode_log(t) = mode;

        d = double(data);
        d(crit) = 1;
        if mode == 1
            [eg, en, Tf, tdone, egs, ens] = frame_cost(1, crit, d, [], prm);
        elseif mode == 2
            [eg, en, Tf, tdone, egs, ens] = frame_cost(2, crit, d, bucket, prm);
        else
            [eg, en, Tf, tdone, egs, ens] = frame_cost(4, crit, d, [], prm);
        end

        excl_last = false(N,1);
        if mode == 2
            nc = ~crit;
            excl_last = nc & bucket == 3;
            bk = bk + [sum(nc & bucket == 1), sum(nc & bucket == 2), sum(nc & bucket == 3)]/max(sum(nc), 1);
            n_hyb = n_hyb + 1;
            fp = fp + sum(nc & bucket == 1 & ~data);
            fn = fn + sum(nc & bucket == 3 & data);
            n_zero = n_zero + sum(nc & ~data);
            n_one = n_one + sum(nc & data);
        end

        aes(crit) = nblk*prm.E_aes256;
        aes(~crit & ~isnan(tdone)) = nblk*prm.E_aes128;
    end

    en = en + aes;
    deliv = data & ~isnan(tdone);

    % bookkeeping of delivered and waiting packets
    got = got + sum(newd(deliv)) + sum(pend(deliv));
    lat = [lat; tdone(deliv & ev)];
    old = deliv & pend_ev;
    lat = [lat; wait_fr(old)*Trep + tdone(old)];
    w = deliv & pend > 0;
    lat_all = [lat_all; tdone(deliv & newd & ~w); wait_fr(w)*Trep + tdone(w)];

    miss = data & ~deliv;
    if strcmp(proto, 'aloha')
        pend(:) = 0;  pend_ev(:) = false;  wait_fr(:) = 0;
    else
        pend(miss) = pend(miss) + newd(miss);
        pend_ev(miss) = pend_ev(miss) | ev(miss);
        wait_fr(miss) = wait_fr(miss) + 1;
        pend(deliv) = 0;  pend_ev(deliv) = false;  wait_fr(deliv) = 0;
    end

    if strcmp(proto, 'nextgen')
        seen_anom = deliv & ev;
    end

    Eg = Eg + eg;  En = En + sum(en);
    Eg_s = Eg_s + egs;  En_s = En_s + sum(ens);
    E_aes = E_aes + sum(aes);
    Enode = Enode + total_energy(en, ens, prm);
end

r.Eg = total_energy(Eg/T, Eg_s/T, prm);
r.En = total_energy(En/T, En_s/T, prm);
r.Etot = r.Eg + r.En;
r.E_aes = total_energy(E_aes/T, 0, prm);
r.Enode = Enode/T;
r.pdr = got/max(gen, 1);
if isempty(lat)
    r.lat = NaN;
else
    r.lat = mean(lat);
end
r.col = ncol/max(ntx, 1);
r.modes = modes/T;
r.rho = rho_log;
r.mode = mode_log;
r.lat_all = mean(lat_all);
r.buckets = bk/max(n_hyb, 1);
r.fpr = fp/max(n_zero, 1);
r.fnr = fn/max(n_one, 1);
r.Trep = Trep;
end
