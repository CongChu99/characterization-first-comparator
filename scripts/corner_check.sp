* corner_check.sp — minimal SKY130 corner validation circuit
* Usage: ngspice -b -o /dev/null corner_check.sp
*        with CORNER and PDK_ROOT set as environment or via .param

.param CORNER=tt
.param PDK_ROOT="/tmp/sky130A"

* SKY130 model library — try both known PDK layout paths
.lib {PDK_ROOT}/libs.ref/sky130_fd_pr/spice/sky130.lib.spice {CORNER}

* Minimal test circuit: NMOS and PMOS divider
M1 vout vg vdd vdd sky130_fd_pr__pfet_01v8 W=1u L=150n
M2 vout vg gnd gnd sky130_fd_pr__nfet_01v8 W=1u L=150n

Vdd vdd gnd DC 1.8
Vg  vg  gnd DC 0.9

.op
.end
