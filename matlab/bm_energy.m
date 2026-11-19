function [Eg, En] = bm_energy(N, p, c, prm)
% BM-LoRa, scenario 2 of base paper (critical + normal nodes)

Td = prm.Td;  Tg = prm.Tg;  Tcp = prm.Tcp;

Nc  = N*c;          % eq 5
Nn  = N*(1 - c);
Nn1 = p*Nn;         % eq 6
Nn2 = (1 - p)*Nn;

% every normal node has its own subslot in the CAP
Tcap = Nn * prm.Tsub;

% eq 11
% note: paper writes Nn here but Fig 4 of the paper only has Nn1 normal
% slots, so gateway listens to Nn1 slots
Eg_act = Tcp*prm.Ptxg + Nc*prm.Prxg*(Td + Tg) + Nn1*prm.Prxg*(Td + Tg) + Tcap*prm.Prxg;

% eq 12
En_act = Nc*Tcp*prm.Prxn ...
       + Nc*( Td*prm.Ptxn + (Nc-1)*Td*prm.Psn + Nn*(Td + Tg)*prm.Psn ) ...
       + Nn1*prm.Ptxn*Tcap + Nn2*prm.Psn*Tcap + Nc*prm.Psn*Tcap ...
       + Nn1*( prm.Ptxn*Td + (Nn1-1)*prm.Psn*Td + Nn1*prm.Psn*Tg ...
       + Nn2*prm.Psn*(Td + Tg) + Nc*(Td + Tg)*prm.Psn );

% eq 13
Eg_slp = Tcp*prm.Psg + Nc*prm.Psg*(Td + Tg) + Nn*prm.Psg*(Td + Tg) + Tcap*prm.Psg;

% eq 14 (paper has Td+Td, we used Td+Tg)
En_slp = Nc*Tcp*prm.Psn + Nc*( N*prm.Psn*(Td + Tg) ) ...
       + Nn1*prm.Psn*Tcap + Nn2*prm.Psn*Tcap + Nc*prm.Psn*Tcap ...
       + Nn1*( N*prm.Psn*(Td + Tg) );

Eg = total_energy(Eg_act, Eg_slp, prm);
En = total_energy(En_act, En_slp, prm);
end
