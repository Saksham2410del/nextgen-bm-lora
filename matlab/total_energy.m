function E = total_energy(E_act, E_slp, prm)
% eq 15, 16 and 17
E = prm.Ncycles * prm.DC * E_act + prm.Ncycles * (1 - prm.DC) * E_slp;
end
