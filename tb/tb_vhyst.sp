* ===========================================================================
* tb_vhyst.sp
* Hysteresis Testbench — SKY130 Differential-Pair Comparator
* Task: characterization-first-comparator-3be.6
* ===========================================================================
*
* Measures:
*   VIN_rise  - INP threshold crossing when sweeping low→high (V)
*   VIN_fall  - INP threshold crossing when sweeping high→low (V)
*   VHYST     - Hysteresis = VIN_fall − VIN_rise (V)
*               Expected: < 1mV (design has no intentional hysteresis)
*
* Spec:
*   VHYST max: 5 mV  (pure mismatch-induced, no intentional hysteresis)
*   Condition: VDD=1.8V, INN=VDD/2, T=27°C
*
* Method:
*   Run DC sweep twice:
*     Forward:  Vinp 0 → VDD (rising) → measure VIN_rise at VOUT=VDD/2
*     Reverse:  Vinp VDD → 0 (falling) → measure VIN_fall at VOUT=VDD/2
*   VHYST = VIN_fall - VIN_rise
*   For a purely combinational comparator: VHYST ≈ 0 (pure offset mismatch)
*
* Corner parameterization (inject via -pre flag or .param override):
*   .param CORNER = "tt"    (tt|ff|ss|fs|sf)
*   .param VDD    = 1.8     (1.62 | 1.8 | 1.98)
*   .param TEMP   = 27      (-40 | 27 | 125)
*
* Usage:
*   ngspice -b tb/tb_vhyst.sp
*   ngspice -b -pre ".param CORNER='ff' VDD=1.98 TEMP=125" tb/tb_vhyst.sp
*
* Output:
*   results/raw/tb_vhyst.raw
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
* ---------------------------------------------------------------------------
Vbias vbias 0 DC {VBIAS}

* ---------------------------------------------------------------------------
* Input stimulus
*
* Vinp: swept via .dc in both directions (forward then reverse)
* Vinn: fixed at VDD/2 as differential reference
* ---------------------------------------------------------------------------
.param VCM = {VDD/2}

Vinp  inp  0  DC 0        $ DC value overridden by .dc sweep
Vinn  inn  0  DC {VCM}    $ INN fixed at VDD/2

* ---------------------------------------------------------------------------
* DUT instantiation
* Port order: INP INN VDD VSS OUT VBIAS
* ---------------------------------------------------------------------------
Xdut  inp  inn  vdd  vss  out  vbias  comparator

* ---------------------------------------------------------------------------
* Load resistor: 1MΩ to prevent floating output node
* ---------------------------------------------------------------------------
Rload  out  0  1Meg

* ---------------------------------------------------------------------------
* DC sweep — bidirectional:
*   Forward (rising):  0 → VDD in +1mV steps → captures VIN_rise
*   Reverse (falling): VDD → 0 in −1mV steps → captures VIN_fall
*
* ngspice .dc supports only one direction per analysis card.
* Two .dc cards are used; the second resets and re-solves from VDD→0.
* ngspice stores both as separate datasets in the raw file.
* ---------------------------------------------------------------------------
.dc Vinp 0 {VDD} 1m
* Note: for bidirectional sweep, ngspice processes two .dc lines sequentially.
* The reverse sweep captures the falling edge threshold.
.dc Vinp {VDD} 0 1m

* ---------------------------------------------------------------------------
* Measurements
*
* VIN_rise: V(inp) when V(out) = VDD/2 on the RISING sweep (dc1)
* VIN_fall: V(inp) when V(out) = VDD/2 on the FALLING sweep (dc2)
* VHYST: hysteresis window = VIN_fall - VIN_rise (should be ~0 for this design)
* ---------------------------------------------------------------------------
.meas dc VIN_rise WHEN v(out)={VDD/2} RISE=1
.meas dc VIN_fall WHEN v(out)={VDD/2} FALL=1
.meas dc VHYST param='VIN_fall - VIN_rise'

* ---------------------------------------------------------------------------
* Save waveforms to results/raw/
* ---------------------------------------------------------------------------
.control
  set filetype = ascii
  set rawfile  = results/raw/tb_vhyst.raw
  run
  write results/raw/tb_vhyst.raw
  quit
.endc

.end
