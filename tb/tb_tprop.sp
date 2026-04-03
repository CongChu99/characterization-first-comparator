* ===========================================================================
* tb_tprop.sp
* Propagation Delay Testbench — SKY130 Differential-Pair Comparator
* Task: characterization-first-comparator-3be.5
* ===========================================================================
*
* Measures:
*   t_prop_hl  - 50% INP rising → 50% OUT falling  (ns)
*   t_prop_lh  - 50% INP falling → 50% OUT rising   (ns)
*
* Spec:
*   typ: 10 ns,  max: 50 ns
*   Condition: VDD=1.8V, Vin_step=100mV overdrive, CL=10fF, T=27°C
*
* Corner parameterization (inject via -pre flag or .param override):
*   .param CORNER = "tt"    (tt|ff|ss|fs|sf)
*   .param VDD    = 1.8     (1.62 | 1.8 | 1.98)
*   .param TEMP   = 27      (-40 | 27 | 125)
*
* Usage:
*   ngspice -b tb/tb_tprop.sp
*   ngspice -b -pre ".param CORNER='ff' VDD=1.98 TEMP=125" tb/tb_tprop.sp
*
* Output:
*   results/raw/tb_tprop_<CORNER>_vdd<VDD>_t<TEMP>.raw
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
* The .lib selector string matches sky130 PDK corner naming convention.
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
* INP: step waveform — swings ±100mV around VDD/2
*   before t=10ns  → VDD/2 − 100mV  (INN wins → OUT high)
*   after  t=10ns  → VDD/2 + 100mV  (INP wins → OUT falls)
*   after  t=110ns → VDD/2 − 100mV  (INN wins → OUT rises)
*
* INN: held at VDD/2 (common-mode reference)
* ---------------------------------------------------------------------------
.param VCM   = {VDD/2}
.param VSTEP = 0.1

Vinp  inp  0  PULSE({VCM-VSTEP} {VCM+VSTEP} 10ns 1ns 1ns 100ns 200ns)
Vinn  inn  0  DC {VCM}

* ---------------------------------------------------------------------------
* DUT instantiation
* Port order: INP INN VDD VSS OUT VBIAS
* ---------------------------------------------------------------------------
Xdut  inp  inn  vdd  vss  out  vbias  comparator

* ---------------------------------------------------------------------------
* Load capacitor: CL = 10fF at OUT (per spec condition)
* ---------------------------------------------------------------------------
CL  out  0  10f

* ---------------------------------------------------------------------------
* Transient analysis
* Run 220ns to capture both HL and LH transitions with margin
* ---------------------------------------------------------------------------
.tran 10p 220n

* ---------------------------------------------------------------------------
* Measurements
*
* t_prop_hl: INP crosses VDD/2 rising (at 10ns) → OUT crosses VDD/2 falling
* t_prop_lh: INP crosses VDD/2 falling (at 110ns) → OUT crosses VDD/2 rising
* ---------------------------------------------------------------------------
.meas tran t_prop_hl
+  TRIG v(inp) VAL={VDD/2} RISE=1
+  TARG v(out) VAL={VDD/2} FALL=1

.meas tran t_prop_lh
+  TRIG v(inp) VAL={VDD/2} FALL=1
+  TARG v(out) VAL={VDD/2} RISE=1

* ---------------------------------------------------------------------------
* Save waveforms to results/raw/
* ---------------------------------------------------------------------------
.control
  set filetype = ascii
  set rawfile  = results/raw/tb_tprop.raw
  run
  write results/raw/tb_tprop.raw
  quit
.endc

.end
