A verified three-bar truss sizing problem, sized to exercise snopta's sparse `A`/`G` Jacobian split (constant linear objective row, nonlinear constraint rows) without needing a full FE assembly to check by hand. The stress equations below are derived from the 2x2 stiffness matrix, not copied from an unverified source, and include a closed-form identity you can use as a standing regression check on your `usrfun`.

## Problem: Three-Bar Truss

Minimize structural weight by sizing two bar areas, subject to stress limits under a combined horizontal/vertical load at the free node.

      P2 ↙   ↘ P1
          *
         /|\
    (1) / | \ (3)
       /  |  \
      / (2)   \
     /    |    \
    ▼     ▼     ▼
   ///   ///   ///

Node layout (H = L = 1.0 m, so bars 1 and 3 are the diagonals and bar 2 is vertical):

* Free node: `(0, 0)` — both loads applied here.
* Support 1 (bar 1, 45°): `(-1, -1)`.
* Support 2 (bar 2, 90°): `(0, -1)`.
* Support 3 (bar 3, 135°): `(1, -1)`.

## 1. Structural Parameters

* Bar areas (design variables): `x1 = A1 = A3` (symmetry), `x2 = A2`.
* Density: ρ = 7800 kg/m³.
* Modulus of elasticity: E = 2.1 × 10¹¹ Pa — cancels out of the stress equations below because all three bars share the same E; it's listed for completeness, not because it appears in the final formulas.
* Allowable stress: σ_allow = 2.0 × 10⁸ Pa, symmetric in tension and compression.
* Loads at the free node: P1 = 20,000 N (horizontal, +x), P2 = -20,000 N (vertical, already signed downward).
* Area bounds: 1.0 × 10⁻⁶ m² ≤ x1, x2 ≤ 1.0 × 10⁻² m².

## 2. Governing Equations

The free node has only two DOF, and by symmetry (bars 1 and 3 mirror each other about the vertical) the 2x2 stiffness matrix is diagonal: `Kxx = E x1 / sqrt(2)`, `Kyy = E x1 / sqrt(2) + E x2`, `Kxy = 0`. Solving `K u = [P1, P2]` and projecting each bar's elongation onto its axis gives, with `D = sqrt(2) x1 + 2 x2`:

* σ1(x) = P1 / (sqrt(2) x1) + P2 / D
* σ2(x) = 2 P2 / D
* σ3(x) = -P1 / (sqrt(2) x1) + P2 / D

These satisfy **σ1 + σ3 = σ2 identically**, for any x1, x2 — a free, x-independent invariant worth asserting in your `usrfun` unit tests before ever calling snopta.

## 3. Optimization Problem

$$\begin{aligned} \text{Minimize: } & f(x) = \rho H (2\sqrt{2}\,x_1 + x_2) \\ \text{Subject to: } & -\sigma_{\text{allow}} \le \sigma_1(x), \sigma_2(x), \sigma_3(x) \le \sigma_{\text{allow}} \\ \text{Bounds: } & 1.0\times10^{-6}\,\text{m}^2 \le x_1, x_2 \le 1.0\times10^{-2}\,\text{m}^2 \end{aligned}$$

Note the stress constraints are two-sided (`Flow = -σ_allow`, `Fupp = +σ_allow`), not one-sided — the ± in the allowable-stress parameter has to show up in the `Flow`/`Fupp` arrays, not just the parameter list.

## 4. snopta Sparse Structure

Lay out `F = [f, σ1, σ2, σ3]` (`ObjRow = 1`, `Flow(1) = Fupp(1) = ±1e20`) over `x = [x1, x2]`:

* Linear part (`A`, constant, row 1 only): `∂f/∂x1 = 2√2 ρH`, `∂f/∂x2 = ρH`.
* Nonlinear part (`G`, recomputed in `usrfun`, rows 2-4, dense in both columns):
  * `∂σ1/∂x1 = -P1/(√2 x1²) - √2 P2/D²`, `∂σ1/∂x2 = -2P2/D²`
  * `∂σ2/∂x1 = -2√2 P2/D²`, `∂σ2/∂x2 = -4P2/D²`
  * `∂σ3/∂x1 = P1/(√2 x1²) - √2 P2/D²`, `∂σ3/∂x2 = -2P2/D²`

So `iGfun = [2,2,3,3,4,4]`, `jGvar = [1,2,1,2,1,2]`, all six entries nonzero at every iterate — a good check that your sparsity declaration isn't accidentally masking a term.

A generic starting guess `x0 = (5.0×10⁻⁴, 5.0×10⁻⁴)` m² (feasible but far from optimal) works fine; SNOPT shouldn't need a warm start for a problem this small.

## 5. Expected Benchmark Solution

Solved via the KKT stationarity condition on the single active constraint (verified numerically by perturbing along the constraint curve in both directions):

* `x1* = A1* = A3* ≈ 1.1154 × 10⁻⁴ m²`
* `x2* = A2* ≈ 5.7735 × 10⁻⁵ m²`
* Minimum weight `f(x*) ≈ 2.911 kg`
* Active constraint: σ3 hits the **compressive** limit, `σ3(x*) ≈ -2.000 × 10⁸ Pa`
* Slack at the optimum: `σ1(x*) ≈ 5.36 × 10⁷ Pa`, `σ2(x*) ≈ -1.464 × 10⁸ Pa` (both strictly inside `±σ_allow`, and `σ1 + σ3 = σ2` still holds as a sanity check).

Only one stress constraint binds at the optimum, so this exercises inequality activation without a degenerate or multi-constraint active set — enough for the optimizer to do real work, without the ambiguity of picking between near-tied active constraints.

## 6. Mapping to the srapnol API

`srapnol` is 0-based (see `docs/SUM.md`), so the snopta layout in section 4 becomes:

* `n = 2`, `nf = 4`, `obj_row = 0`
* `a.rows = [0, 0]`, `a.cols = [0, 1]`, `a.vals = [2√2 ρH, ρH]`
* `g.rows = [1, 1, 2, 2, 3, 3]`, `g.cols = [0, 1, 0, 1, 0, 1]`
* the callback writes `f = [0, σ1, σ2, σ3]` (the objective row is entirely linear, so its nonlinear part is zero) and the six `G` values in pattern order; the solver adds `A x` itself.

`test/truss.zig` carries this transcription as `Truss`; `Truss.optimum()` is the closed form below, and the test rig checks it against the numbers in section 5 before the solver is ever called.

## 7. Closed-Form Optimum

With `P1 = -P2 = P` and only σ3 binding, stationarity (`∇f` parallel to `∇σ3`) reduces to `D² = 6 x1²`, i.e. `x2 = (√6 - √2) x1 / 2`; substituting into `σ3 = -σ_allow` then fixes `x1`:

* `x1* = (P/σ_allow)(1/√2 + 1/√6) = 1.115355 × 10⁻⁴ m²`
* `x2* = (P/σ_allow)/√3 = 5.773503 × 10⁻⁵ m²`
* `f* = ρH (2 + √3)(P/σ_allow) = 2.910999 kg`
* `λ* = ρH / (∂σ3/∂x2) = ρH D²/(2P) = 1.4555 × 10⁻⁸ kg/Pa`, the multiplier of the binding row (positive, as it is a lower bound)

These agree with section 5 and are what `test/truss.zig` asserts to 1e-14 relative; the general-load form (`r = √(-6 P2/P1)`, `x1* = (P1/√2 - P2/r)/σ_allow`) is implemented in `Truss.optimum`.
