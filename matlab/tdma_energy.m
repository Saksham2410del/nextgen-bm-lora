function [Eg, En] = tdma_energy(N, prm)
% TDMA-LoRa, scenario 1 of base paper (all nodes get a slot)

Td = prm.Td;  Tg = prm.Tg;  Tcp = prm.Tcp;

% active period, eq 7 and eq 8
Eg_act = Tcp*prm.Ptxg + N*(Td + Tg)*prm.Prxg;
En_act = N*( Tcp*prm.Prxn + Td*prm.Ptxn + (N-1)*Td*prm.Psn + N*Tg*prm.Psbn );

% sleep period, eq 9 and eq 10
Eg_slp = Tcp*prm.Psg + N*(Td + Tg)*prm.Psg;
En_slp = N*( Tcp*prm.Psn + N*(Td + Tg)*prm.Psn );

Eg = total_energy(Eg_act, Eg_slp, prm);
En = total_energy(En_act, En_slp, prm);
end
