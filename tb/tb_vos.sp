* ===========================================================================
* tb_vos.sp
* Input Offset Voltage Testbench — SKY130 Differential-Pair Comparator
* Task: characterization-first-comparator-3be.6
* ===========================================================================
*
* Measures:
*   VOS  - Input-referred offset voltage (mV)
*          VOS = V(inp) at which V(out) = VDD/2
*
* Spec:
*   typ: 0 mV,  max: ±5 mV
*   Condition: VDD=1.8V, INN=VDD/2, T=27°C
*
* Method:
*   Sweep Vinp from 0 to VDD with Vinn fixed at VDD/2.
*   A positive VOS means INP must be raised above VDD/2 to flip the output,
*   i.e., the comparator is biased toward INP-low by its internal mismatch.
*
* Corner parameterization (inject via -pre flag or .param override):
*   .param CORNER = "tt"    (tt|ff|ss|fs|sf)
*   .param VDD    = 1.8     (1.62 | 1.8 | 1.98)
*   .param TEMP   = 27      (-40 | 27 | 125)
*
* Usage:
*   ngspice -b tb/tb_vos.sp
*   ngspice -b -pre ".param CORNER='ss' VDD=1.62 TEMP=-40" tb/tb_vos.sp
*
* Output:
*   results/raw/tb_vos.raw
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
* Vinp: swept from 0 to VDD (via .dc analysis below)
* Vinn: fixed at VDD/2 — common-mode reference for offset measurement
*
* VOS definition: VOS = V(inp) − VDD/2  when  V(out) = VDD/2
* Positive VOS → M1 (INP side) is weaker → need higher INP to flip output
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
* Load resistor: 1MΩ avoids floating output during DC sweep
* ---------------------------------------------------------------------------
Rload  out  0  1Meg

* ---------------------------------------------------------------------------
* DC sweep: sweep Vinp from 0V to VDD in 1mV steps to find crossing
* ---------------------------------------------------------------------------
.dc Vinp 0 {VDD} 1m

* ---------------------------------------------------------------------------
* Measurements
*
* VOS_val: V(inp) value at which V(out) = VDD/2 (interpolated by ngspice)
* VOS: offset relative to VCM = VOS_val − VDD/2
* ---------------------------------------------------------------------------
.meas dc VOS_val WHEN v(out)={VDD/2}
.meas dc VOS param='VOS_val - VCM'

* ---------------------------------------------------------------------------
* Save waveforms to results/raw/
* ---------------------------------------------------------------------------
.control
  set filetype = ascii
  set rawfile  = results/raw/tb_vos.raw
  run
  write results/raw/tb_vos.raw
  quit
.endc

.end
