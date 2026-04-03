* ===========================================================================
* tb_idd.sp
* Quiescent Current Testbench — SKY130 Differential-Pair Comparator
* Task: characterization-first-comparator-3be.7
* ===========================================================================
*
* Measures:
*   Idd  - Quiescent (static) supply current (µA)
*
* Spec:
*   typ: 100 µA,  max: 200 µA
*   Condition: VDD=1.8V, INP=INN=VDD/2, OUT unloaded, T=27°C
*
* Corner parameterization (inject via -pre flag or .param override):
*   .param CORNER = "tt"    (tt|ff|ss|fs|sf)
*   .param VDD    = 1.8     (1.62 | 1.8 | 1.98)
*   .param TEMP   = 27      (-40 | 27 | 125)
*
* Usage:
*   ngspice -b tb/tb_idd.sp
*   ngspice -b -pre ".param CORNER='ff' VDD=1.98 TEMP=125" tb/tb_idd.sp
*
* Output:
*   results/raw/tb_idd.raw
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
* Supply current is measured as I(Vvdd) — Vvdd is a 0V series-sense source
* acting as an ammeter in the VDD rail.
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
* Idd condition: INP = INN = VDD/2 (common-mode, balanced inputs)
* Output is left unloaded; comparator is in metastable region.
* ---------------------------------------------------------------------------
.param VCM = {VDD/2}

Vinp  inp  0  DC {VCM}
Vinn  inn  0  DC {VCM}

* ---------------------------------------------------------------------------
* DUT instantiation
* Port order: INP INN VDD VSS OUT VBIAS
* ---------------------------------------------------------------------------
Xdut  inp  inn  vdd  vss  out  vbias  comparator

* ---------------------------------------------------------------------------
* DC operating point analysis
* ---------------------------------------------------------------------------
.op

* ---------------------------------------------------------------------------
* Measurement: Quiescent current from VDD rail
* I(Vvdd) is positive when current flows from + to − terminal of Vvdd,
* i.e., into the vdd node. Idd is reported as positive magnitude.
* ---------------------------------------------------------------------------
.meas op Idd param='-I(Vvdd)'

* ---------------------------------------------------------------------------
* Save waveforms to results/raw/
* ---------------------------------------------------------------------------
.control
  set filetype = ascii
  set rawfile  = results/raw/tb_idd.raw
  run
  write results/raw/tb_idd.raw
  quit
.endc

.end
