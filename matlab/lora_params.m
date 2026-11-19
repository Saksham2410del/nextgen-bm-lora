function prm = lora_params(SF, payload)
% all power values are from Table 3 of the base paper
% SX1301 for gateway and SX1276 for end node, 3.3 V supply

V = 3.3;

prm.Ptxg = 7.5e-3 * V;
prm.Prxg = 7.5e-3 * V;
prm.Psg  = 1e-6 * V;

prm.Ptxn = 20e-3 * V;
prm.Prxn = 11.5e-3 * V;
prm.Psbn = 1.8e-3 * V;
prm.Psn  = 0.6e-6 * V;

prm.SF = SF;
prm.BW = 125e3;
prm.CR = 4/8;
prm.payload = payload;

% eq 3 and eq 4
prm.Tsym  = 2^SF / prm.BW;
prm.Rdata = SF * prm.CR * prm.BW / 2^SF;

% packet length in bits, eq 1
preamble      = 6 * SF;
mand_preamble = 4.25 * SF;
phy_header    = 1.5 * 8;
crc           = 2 * 8;
Tlen = preamble + mand_preamble + phy_header + payload*8 + crc;
prm.Td = Tlen / prm.Rdata;

% control packet, eq 2 (preamble + 1 byte payload)
prm.Tcp = (preamble + 8) / prm.Rdata;

% these are not given in the paper (see readme)
prm.Tg   = prm.Tsym;              % guard time = one symbol
prm.Tsub = prm.Tsym + prm.Tg;     % one CAP subslot = request symbol + guard
prm.Ncycles = 20;
prm.DC = 0.1;                     % 10 percent duty cycle (EU868 g3 sub-band)

% AES energy per 16 byte block (few uJ, AES-256 is 22.8% more, ref [10])
prm.E_aes128 = 2.5e-6;
prm.E_aes256 = 2.5e-6 * 1.228;
end
