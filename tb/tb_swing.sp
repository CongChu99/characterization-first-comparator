* ===========================================================================
* tb_swing.sp
* Output Swing Testbench — SKY130 Differential-Pair Comparator
* Task: characterization-first-comparator-3be.7
* ===========================================================================
*
* Measures:
*   VOH  - Output high voltage when INP >> INN  (V)
*   VOL  - Output low voltage  when INP << INN  (V)
*
* Spec:
*   VOH min: VDD − 0.2V  (i.e. ≥ 1.6V at VDD=1.8V)
*   VOL max: 0.2V
*   Condition: VDD=1.8V, INP/INN at rails (0 or VDD), CL=open, T=27°C
*
* Corner parameterization (inject via -pre flag or .param override):
*   .param CORNER = "tt"    (tt|ff|ss|fs|sf)
*   .param VDD    = 1.8     (1.62 | 1.8 | 1.98)
*   .param TEMP   = 27      (-40 | 27 | 125)
*
* Usage:
*   ngspice -b tb/tb_swing.sp
*   ngspice -b -pre ".param CORNER='ss' VDD=1.62 TEMP=-40" tb/tb_swing.sp
*
* Output:
*   results/raw/tb_swing.raw
* ===========================================================================

* ---------------------------------------------------------------------------
* Corner / PVT parameters (defaults = TT nominal)
* ---------------------------------------------------------------------------
.param CORNER = "tt"
.param VDD    = 1.8
.param TEMP   = 27
.param VBIAS  = 0.55

* Set simulation temperature
.temp {TEMP}

* ---------------------------------------------------------------------------
* PDK model include — keyed by CORNER parameter
* ---------------------------------------------------------------------------
* SKY130 models are loaded via the corner-specific lib file.
* PDK_ROOT must be set in the environment; ngspice resolves $PDK_ROOT.
*
.lib $PDK_ROOT/libs.tech/ngspice/sky130.lib.spice {CORNER}

* ---------------------------------------------------------------------------
* Include DUT subcircuit
* ---------------------------------------------------------------------------
.include ../netlist/comparator.spice

* ---------------------------------------------------------------------------
* Supply nets
* ---------------------------------------------------------------------------
Vvdd  vdd  0  DC {VDD}
Vvss  vss  0  DC 0

* ---------------------------------------------------------------------------
* VBIAS for tail current source (M5)
* VBIAS=0.55V → VGS_M5 = VDD−VBIAS ≈ 1.25V → Itail ≈ 100µA at TT/27°C
* ---------------------------------------------------------------------------
Vbias vbias 0 DC {VBIAS}

* ---------------------------------------------------------------------------
* Input stimulus
*
* VOH condition: INP = VDD  (INP >> INN → output should be HIGH)
* VOL condition: INP = 0    (INP << INN → output should be LOW)
* INN is held at VDD/2 as a stable common-mode reference.
*
* DC sweep: sweep Vinp from 0 to VDD in two points (0 and VDD)
* to capture both VOL and VOH in a single .dc simulation.
* ---------------------------------------------------------------------------
Vinp  inp  0  DC {VDD}
Vinn  inn  0  DC {VDD/2}

* ---------------------------------------------------------------------------
* Load resistor: 1MΩ at OUT to avoid floating output node.
* High resistance preserves logic levels while allowing proper DC solution.
* ---------------------------------------------------------------------------
Rload out 0 1Meg

* ---------------------------------------------------------------------------
* DUT instantiation
* Port order: INP INN VDD VSS OUT VBIAS
* ---------------------------------------------------------------------------
Xdut  inp  inn  vdd  vss  out  vbias  comparator

* ---------------------------------------------------------------------------
* DC sweep: sweep INP (Vinp) from 0V to VDD in 2 steps
*   Step 0: Vinp=0V  → INP << INN → OUT should be LOW  → measure VOL
*   Step 1: Vinp=VDD → INP >> INN → OUT should be HIGH → measure VOH
* ---------------------------------------------------------------------------
.dc Vinp 0 {VDD} {VDD}

* ---------------------------------------------------------------------------
* Measurements
*
* VOH: V(out) when Vinp = VDD (INP >> INN)
* VOL: V(out) when Vinp = 0   (INP << INN)
* ---------------------------------------------------------------------------
.meas dc VOH find V(out) when V(inp)={VDD}
.meas dc VOL find V(out) when V(inp)=0

* ---------------------------------------------------------------------------
* Save waveforms to results/raw/
* ---------------------------------------------------------------------------
.control
  set filetype = ascii
  set rawfile  = results/raw/tb_swing.raw
  run
  write results/raw/tb_swing.raw
  quit
.endc

.end
