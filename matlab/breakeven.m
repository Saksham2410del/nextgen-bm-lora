function [Astar, Alist, Eng, Ebm] = breakeven(N, p, prm)
% minimum prediction accuracy for which next gen uses less energy than BM-LoRa
% same critical nodes as base paper (c = 0.5) so only prediction is compared
% simple two bucket case: node predicted to send -> promoted, else excluded
% sleep power terms are left out (micro watt, very small)

Td = prm.Td;  Tg = prm.Tg;  Tcp = prm.Tcp;  Tsub = prm.Tsub;
Nc = N/2;
Nn = N/2;

% BM-LoRa (eq 11 and 12, main terms)
Eg_bm = Tcp*prm.Ptxg + (Nc + p*Nn)*(Td + Tg)*prm.Prxg + Nn*Tsub*prm.Prxg;
En_bm = Nc*Tcp*prm.Prxn + Nc*Td*prm.Ptxn + p*Nn*(prm.Ptxn*Nn*Tsub + prm.Ptxn*Td);
Ebm = prm.Ncycles*prm.DC*(Eg_bm + En_bm);

Alist = 0:0.001:1;
Eng = zeros(size(Alist));
for k = 1:length(Alist)
    a = Alist(k);
    TP = a*p*Nn;                 % predicted to send and has data
    FP = (1-a)*(1-p)*Nn;         % slot given but nothing to send
    FN = (1-a)*p*Nn;             % has data but excluded, sends next frame
    Tcap = FN*Tsub;              % small CAP only for missed nodes

    Eg = Tcp*prm.Ptxg + (Nc + TP + FP + FN)*(Td + Tg)*prm.Prxg + Tcap*prm.Prxg;
    En = N*Tcp*prm.Prxn + Nc*Td*prm.Ptxn + (TP + FN)*Td*prm.Ptxn + FN*prm.Ptxn*Tcap;
    Eng(k) = prm.Ncycles*prm.DC*(Eg + En);
end

idx = find(Eng <= Ebm, 1);
if isempty(idx)
    Astar = NaN;
else
    Astar = Alist(idx);
end
end
