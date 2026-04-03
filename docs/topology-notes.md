# Comparator Topology Notes

## Design: Static NMOS Differential-Pair Comparator

**Process:** SKY130 1.8V (sky130_fd_pr)
**Supply:** VDD = 1.8V, VSS = 0V
**Target:** Idd ≈ 100 µA at TT/27°C

---

## Topology Choice Rationale

The v1 comparator uses a **static NMOS differential pair with a PMOS current mirror load**. This topology was selected for the following reasons:

1. **Simplicity and predictability** — The differential pair is a well-understood analog building block. Its DC operating point, gain, and offset are analytically tractable, making it straightforward to validate in simulation before silicon.

2. **Static (always-on) operation** — Unlike dynamic topologies (e.g., StrongARM latch), this comparator draws continuous quiescent current. For a characterization vehicle, predictable DC behavior is more useful than power efficiency.

3. **Direct testbench integration** — The circuit has a rail-to-rail-compatible output (drain of M2/M4) and a single bias voltage (VBIAS), which maps cleanly to the planned testbench structure without requiring clock generation or reset signals.

4. **SKY130 compatibility** — Only `sky130_fd_pr__nfet_01v8` and `sky130_fd_pr__pfet_01v8` are used, both well-characterized 1.8V devices available in the open-source SKY130 PDK.

---

## Device Sizing Rationale

| Ref | Type  | W    | L     | nf | Function              |
|-----|-------|------|-------|----|-----------------------|
| M1  | NFET  | 2 µm | 500 nm | 2 | Input+ diff-pair      |
| M2  | NFET  | 2 µm | 500 nm | 2 | Input− diff-pair      |
| M3  | PFET  | 4 µm | 500 nm | 2 | Current mirror ref    |
| M4  | PFET  | 4 µm | 500 nm | 2 | Current mirror output |
| M5  | PFET  | 8 µm | 500 nm | 4 | Tail current source   |

### Input pair (M1, M2): W=2µm, L=500nm, nf=2
- L=500nm (minimum for 1.8V devices in SKY130) provides a balance between speed and matching. A longer channel would improve matching (lower Vos) at the cost of bandwidth.
- W=2µm per device with nf=2 fingers gives W_per_finger=1µm, which is within the recommended layout range for SKY130 standard devices.
- The modest width keeps the input capacitance low while providing sufficient gm for reasonable gain (gm ≈ 2·ID/Vov).

### PMOS load mirror (M3, M4): W=4µm, L=500nm, nf=2
- PMOS devices are sized at 2× the NMOS width to compensate for the lower hole mobility (~µp ≈ µn/2 in SKY130), ensuring roughly matched drain currents at the same Vgs overdrive.
- Diode-connected M3 (gate tied to drain) sets the mirror reference; M4 replicates the current to the output node.

### Tail current source (M5): W=8µm, L=500nm, nf=4
- M5 is sized at 4× M1/M2 width (8µm) to set a tail current of ~100µA. With VBIAS ≈ 0.5–0.6V (referenced to VDD), the PMOS Vsg is sufficient to push the device into saturation and deliver the desired Itail.
- nf=4 fingers distributes the current across more channels, reducing per-finger stress and improving matching to the mirror reference branch.

---

## Expected Operating Point (TT/27°C, VDD=1.8V)

| Parameter          | Expected value     |
|--------------------|--------------------|
| Itail (through M5) | ~100 µA            |
| ID (M1 = M2)       | ~50 µA each        |
| VBIAS (for Itail)  | ~0.5–0.6V          |
| VGS_tail (M5)      | VDD − VBIAS ≈ 1.2–1.3V |
| Vov (M1/M2)        | ~150–200 mV        |
| DC gain (Av)       | ~gm·(rds2 ‖ rds4)  |

---

## VBIAS Recommendation

For a tail current of ~100 µA with M5 (W=8µm, L=500nm, nf=4, PMOS):

- Set VBIAS between **0.5V and 0.6V** (i.e., VGS_M5 = VDD − VBIAS ≈ 1.2–1.3V).
- For initial testbench runs, use **VBIAS = 0.55V** as a nominal starting point; sweep 0.4V–0.7V to characterize Itail vs. VBIAS.
- In a real system, VBIAS would be derived from a bandgap-referenced bias generator. For characterization, a DC voltage source is sufficient.

---

## Known Limitations vs. StrongARM Latch

| Aspect              | Static Diff-Pair (this design)     | StrongARM Latch              |
|---------------------|------------------------------------|------------------------------|
| Quiescent current   | ~100 µA continuous                 | Near-zero (dynamic)          |
| Speed               | Limited by RC time constants       | Very fast (regenerative)     |
| Power efficiency    | Poor for high-speed apps           | Excellent                    |
| Metastability       | Output follows input continuously  | Resolved per clock edge      |
| Offset              | Static Vos from device mismatch    | Dynamic offset + hysteresis  |
| Complexity          | Low — no clock/reset needed        | Higher — clocked topology    |
| Suitability         | DC/low-freq characterization, ADC input stage | High-speed ADC, SerDes |

The static topology is the correct choice for **v1 characterization**: it allows DC sweep measurements, offset characterization, and gain extraction without requiring a clock. A StrongARM implementation would be a natural v2 upgrade for any application requiring high speed or low power.
