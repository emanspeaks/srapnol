# Software Data Dictionary

| Field | Value |
| --- | --- |
| Identifier | SRAPNOL-SDD |
| Revision | 0.1 (draft) |
| Date | 2026-09-15 |
| Prepared by | Randy Eckman, maintainer |

Content follows NASA-HDBK-2203 topic 5.07. Every data element crossing the library
boundary is listed with type, units, range or limits, default, and source and
destination. Elements of the C ABI have the same names and meanings (IDD).

## Revision history

| Revision | Date | Description |
| --- | --- | --- |
| 0.1 | 2026-09-15 | Initial dictionary. |

## 1. Applicability of handbook items

| HDBK 5.07 item | Applicability |
| --- | --- |
| Channelization data, rate groups, sensor data, telemetry, data recorder, command definitions, effecter commands, scheduling and inter-task communication, partitioning | Not applicable: the library has no hardware channels, telemetry, commands, tasks, or partitions |
| Input/output variables, operational limits | Sections 2 through 7 |

Units: the library is unit-agnostic; `x`, `F`, `A`, and `G` carry whatever units the
host's model uses. Tolerances are dimensionless relative measures unless noted.

## 2. Problem (input)

| Element | Type | Range or limits | Default | Source | Destination |
| --- | --- | --- | --- | --- | --- |
| `n` | `usize` | `>= 1` | none | host | validation, workspace sizing |
| `nf` | `usize` | `>= 1` | none | host | validation, workspace sizing |
| `obj_row` | `?u32` | `< nf`, or null for feasible-point mode | `null` | host | objective selection |
| `obj_add` | `f64` | finite | `0` | host | `Result.objective` |
| `x_low`, `x_upp` | `[]const f64`, length `n` | `x_low[j] <= x_upp[j]`; `\|v\| >= infinite_bound` means absent; no NaN | none | host | bounds |
| `f_low`, `f_upp` | `[]const f64`, length `nf` | as above; objective row ignored | none | host | row bounds |
| `a.rows`, `a.cols` | `[]const u32`, equal length `na` | `rows < nf`, `cols < n`; no duplicate slot; disjoint from `g` | empty | host | constant part `A` |
| `a.vals` | `[]const f64`, length `na` | finite | empty | host | `A` |
| `g.rows`, `g.cols` | `[]const u32`, equal length `ng` | as for `a`; disjoint from `a` | empty | host | Jacobian pattern |
| `eval` | `EvalFn` | non-null | none | host | callback |
| `ctx` | `?*anyopaque` | any | `null` | host | passed to callback |
| `name` | `[]const u8` | any | `""` | host | diagnostics |

## 3. Request and callback outputs

| Element | Type | Range or limits | Source | Destination |
| --- | --- | --- | --- | --- |
| `x` | `[]const f64`, length `n` | within bounds and linear rows (never outside) | solver | callback |
| `f` | `?[]f64`, length `nf` | finite (NaN or infinity is treated as undefined); linear rows written as 0 | callback | solver |
| `g` | `?[]f64`, length `ng` | pattern order; NaN allowed only with `derivative_option == .some_missing` | callback | solver |
| `status` | `Status` | `.first` once, `.normal`, `.last` once | solver | callback |
| return | `EvalError!void` | `Undefined`: not evaluable here; `Abort`: stop | callback | solver |

## 4. Options

| Field | SNOPT keyword | Type | Range | Default | Notes |
| --- | --- | --- | --- | --- | --- |
| `major_iterations_limit` | Major iterations limit | `u32` | `>= 1` | 1000 | exit 32 when exceeded |
| `minor_iterations_limit` | Minor iterations limit | `u32` | `>= 1` | 500 | per QP subproblem |
| `iterations_limit` | Iterations limit | `u32` | `>= 1` | 10000 | total minor iterations; exit 31 |
| `major_feasibility_tolerance` | Major feasibility tolerance | `f64` | `> 0` | 1e-6 | nonlinear rows, scaled by `1 + \|\|x\|\|` |
| `major_optimality_tolerance` | Major optimality tolerance | `f64` | `> 0` | 1e-6 | scaled by `max(1, \|\|pi\|\|)` |
| `minor_feasibility_tolerance` | Minor feasibility tolerance | `f64` | `> 0` | 1e-6 | bounds and linear rows |
| `derivative_option` | Derivative option | enum | `.some_missing` (0), `.all_provided` (1) | `.all_provided` | |
| `verify_level` | Verify level | enum(i8) | `.off` (-1), `.cheap` (0), `.objective` (1), `.constraints` (2), `.all` (3) | `.off` | |
| `hessian` | Hessian full memory / limited memory | enum | `.limited_memory`, `.full_memory` | `.limited_memory` | |
| `hessian_updates` | Hessian updates | `u32` | `>= 1` | 10 | pairs before a limited-memory reset |
| `elastic_weight` | Elastic weight | `f64` | `> 0` | 1e4 | initial `gamma` |
| `infinite_bound` | Infinite bound | `f64` | `> 0` | 1e20 | |
| `scale_option` | Scale option | enum(u8) | `.none` (0), `.linear` (1), `.all` (2) | `.linear` | |
| `function_precision` | Function precision | `f64` | `> 0` | 3.0e-13 | about eps^0.8 |
| `difference_interval` | Difference interval | `f64` | `> 0` | 5.5e-7 | about eps^0.4 |
| `central_difference_interval` | Central difference interval | `f64` | `> 0` | 6.7e-5 | about eps^(1/3) |
| `linesearch_tolerance` | Linesearch tolerance | `f64` | `[0, 1)` | 0.9 | 0.9 loose, 0.1 nearly exact |
| `major_step_limit` | Major step limit | `f64` | `> 0` | 2.0 | relative to `1 + \|\|x\|\|` |
| `penalty_parameter` | Penalty parameter | `f64` | `>= 0` | 0.0 | initial merit penalty |
| `superbasics_limit` | Superbasics limit | `?u32` | `>= 1` or null | `null` = `min(500, n + 1)` | exit 33 |
| `unbounded_objective` | Unbounded objective | `f64` | `> 0` | 1e15 | exit 21 |
| `unbounded_step_size` | Unbounded step size | `f64` | `> 0` | 1e18 | exit 21 |
| `violation_limit` | Violation limit | `f64` | `> 0` | 10.0 | exit 22 |
| `major_print_level` | Major print level | `u32` | `>= 0` | 1 | 0 silent even with a writer |
| `minor_print_level` | Minor print level | `u32` | `>= 0` | 0 | |
| `writer` | Print file / Summary file | `?*std.Io.Writer` | any | `null` | null is silent |

Invalid values are rejected by `Solver.init` with `error.InvalidOption` (planned).

## 5. State (input and output)

| Element | Type | Length | Input use | Output meaning | Limits |
| --- | --- | --- | --- | --- | --- |
| `x` | `[]f64` | `n` | starting point | solution | finite; within bounds on exit |
| `x_state` | `[]VarState` | `n` | basis hint (`.basis`, `.warm`) | active set | `nonbasic_lower` 0, `nonbasic_upper` 1, `superbasic` 2, `basic` 3 |
| `x_mul` | `[]f64` | `n` | multiplier hint (`.warm`) | bound multipliers | `>= 0` at lower bound, `<= 0` at upper |
| `f` | `[]f64` | `nf` | ignored | full `F(x)` | finite |
| `f_state` | `[]VarState` | `nf` | basis hint | active set | as `x_state` |
| `f_mul` | `[]f64` | `nf` | multiplier hint (`.warm`) | row multipliers | sign as `x_mul`; `f_mul[obj_row] == 0` |

## 6. Result (output)

| Element | Type | Range | Meaning |
| --- | --- | --- | --- |
| `exit` | `Exit` (enum(u8)) | snOptA INFO codes 1..71 (SUM table) | termination reason |
| `objective` | `f64` | finite | `obj_add + F[obj_row]`, or 0 in feasible-point mode |
| `major_iterations` | `u32` | `<= major_iterations_limit` | |
| `minor_iterations` | `u32` | `<= iterations_limit` | total |
| `function_evaluations` | `u32` | | callbacks requesting `f` |
| `jacobian_evaluations` | `u32` | | callbacks requesting `g` |
| `num_infeasibilities` | `u32` | | snOptA `nInf` |
| `sum_infeasibilities` | `f64` | `>= 0` | snOptA `sInf` |
| `superbasics` | `u32` | `<= superbasics_limit` | snOptA `nS` |
| `primal_infeasibility` | `f64` | `>= 0` | scaled max nonlinear row violation at exit |
| `dual_infeasibility` | `f64` | `>= 0` | scaled max complementarity at exit |

## 7. Operational limits

| Limit | Value | Basis |
| --- | --- | --- |
| Maximum `nf` with the dense basis | 2000 rows (SRS section 4) | `O(nf^2)` memory, `O(nf^3)` refactorization |
| Workspace | function of `n`, `nf`, `nnz(A)`, `nnz(G)`, options (DES resources item) | sized once at `init` |
| Precision | IEEE 754 binary64 throughout | SRS section 2.5 |
| Indices | `u32`, so `n`, `nf < 2^32` | interface definition |

## 8. Error sets

| Set | Members |
| --- | --- |
| `Problem.ValidateError` | `NoVariables`, `NoFunctions`, `LengthMismatch`, `InvertedBounds`, `NonFiniteValue`, `ObjRowOutOfRange`, `IndexOutOfRange`, `DuplicateEntry`, `OverlappingEntry`, `OutOfMemory` |
| `Problem.EvalError` | `Undefined`, `Abort` |
| `State.InitError` | `OutOfMemory`, `LengthMismatch` |
| `Solver.Error` | `ValidateError` members, `NotImplemented` (stub), `InvalidOption` (planned) |
