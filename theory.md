# Theory and design

The mathematics behind each component, in the order the solver applies them, and the
choices that turn SNOPT's published design into this implementation. References are in
section 11; "GMS" is Gill, Murray, and Saunders (2005) throughout.

## 1. Problem transformation

The user problem (PRB-1) is

```text
minimize    F_obj(x)
subject to  x_low <= x <= x_upp,   f_low <= F(x) <= f_upp,   F(x) = f(x) + A x.
```

Internally:

1. **Slacks (ALG-2).** Introduce `s` in `R^nf` and write `F(x) - s = 0`, `f_low <= s <= f_upp`. Every general constraint is now an equality and every inequality a simple bound. The combined vector `(x, s)` has `n + nf` components; the constraint matrix at a point is `[J  -I]` with `J = G(x) + A`.
2. **Objective row.** Row `obj_row` leaves the constraint set: its `F` value is the objective, its slack is unused, its bounds are ignored (PRB-10). With `obj_row == null` the objective is identically 0 (PRB-6).
3. **Linear and nonlinear partition.** Rows with no `G` entries are *linear rows*; columns with no `G` entries are *linear variables*. Only nonlinear rows enter the merit function and elastic mode; only nonlinear variables carry Hessian curvature. This is why the objective's linear part belongs in `A` (truss weight, toy `x2`): it keeps the Hessian small and the linear part exact.
4. **Infinite bounds (PRB-4)** are dropped; a variable free on both sides starts nonbasic at `x0`.
5. **Scaling (ALG-10).** With `scale_option != .none`, row and column factors `r_i`, `c_j` come from the iterative geometric-mean procedure of Fourer (1982) on `[A ; G(x0)]`, so scaled entries `r_i J_ij c_j` have magnitudes near 1; the solver then works on `x' = x / c`, `F' = r F`. Everything user-visible is unscaled on the way in and out. The truss problem is the motivating case: `x ~ 1e-4`, `F ~ 1e8`, `G ~ 1e12`.

## 2. SQP outline

Major iteration `k` holds `x_k`, `s_k`, multipliers `pi_k`, a penalty vector `D_k`, and a Hessian approximation `H_k` (section 5).

1. Evaluate `f(x_k)` and `G(x_k)`; form `F_k` and `J_k`.
2. Solve the QP subproblem (section 3) for a direction `(d_x, d_s)` and new multipliers `pi_hat`.
3. Update the penalties `D` so the merit function has sufficient descent along `(d_x, d_s, pi_hat - pi_k)` (section 4).
4. Line search on the merit function for a step `alpha`; set `x_{k+1} = x_k + alpha d_x`, likewise `s` and `pi`.
5. Update `H` from the change in `x` and in the Lagrangian gradient (section 5).
6. Test convergence (section 7); otherwise repeat.

Bounds and linear rows are satisfied before step 1 ever runs (ALG-3): a first feasibility-phase QP with no objective finds a linearly feasible `x_0`; if none exists the solve exits 11 or 12. Every later QP keeps the linear rows feasible, so `f` is evaluated only at linearly feasible points.

## 3. The QP subproblem and its active-set method

### 3.1 Formulation

```text
minimize over (x, s)   g_k'(x - x_k) + 1/2 (x - x_k)' H_k (x - x_k)
subject to             F_k + J_k (x - x_k) - s = 0
                       x_low <= x <= x_upp,  f_low <= s <= f_upp
```

`g_k` is the objective gradient (row `obj_row` of `J_k`, or 0). The linearized rows are equalities in `(x, s)`; the only inequalities are bounds, which is what the active-set method exploits.

### 3.2 Basic, superbasic, nonbasic

With `m = nf - 1` constraint rows (objective row removed) and `n + nf` columns in `[J  -I]`, partition the columns into

- **Basic** `B`: `m` columns forming a nonsingular square matrix;
- **Superbasic** `S`: `nS` columns free to move strictly between their bounds;
- **Nonbasic** `N`: columns fixed at a bound.

Any step `p` that keeps the equalities satisfies `B p_B + S p_S = 0` and `p_N = 0`, so `p = Z p_S` with

```text
Z = [ -B^{-1} S ]
    [     I     ]
    [     0     ]
```

`Z` is never formed: `Z v` and `Z' w` cost one solve with `B` (or `B'`) plus a sparse product with `S`. The reduced gradient is `Z' g` and the reduced Hessian `Z' H Z` is held as a dense upper-triangular Cholesky factor `R` (`R'R = Z'HZ`) of dimension `nS` (ALG-4, NUM-4). This is the SQOPT design; the dense `R` is why `superbasics_limit` exists.

### 3.3 Minor iteration

1. **Multipliers.** Solve `B' pi = g_B`. Reduced costs for the nonbasics: `sigma_N = g_N - N' pi`.
2. **Optimality of the current face.** If `Z'g` is small and every nonbasic reduced cost has the right sign (`sigma_j >= 0` at a lower bound, `<= 0` at an upper bound, within tolerance), the QP is solved.
3. **Pricing.** Otherwise, if `Z'g` is small, pick the nonbasic with the worst-signed reduced cost and make it superbasic: `nS += 1`, and `R` gains a column through a solve with `R'`.
4. **Direction.** Solve `R'R p_S = -Z'g`; `p = Z p_S`.
5. **Ratio test.** The largest `alpha <= 1` that keeps every basic and superbasic variable within its bounds. Degeneracy (ties, zero steps) is handled by the EXPAND procedure of Gill, Murray, Saunders, and Wright (1989): the working feasibility tolerance grows slightly each iteration and is reset periodically, guaranteeing a nonzero step and preventing cycling.
6. **Update.** Take the step. If a basic variable hit a bound, swap it with a superbasic: the LU factors of `B` are updated (ALG-14) and `R` is corrected by a rank-one update. If a superbasic hit a bound, it becomes nonbasic and its column leaves `R` through a sweep of Givens rotations. If `alpha = 1`, the current face's minimizer was reached.

Each minor iteration costs a few solves with `B`, products with `S`, and `O(nS^2)` work on `R`. The SIMD hot spots are the triangular solves and rotations on `R`, the dense LU operations on `B`, and the dense vector updates (NUM-2, NUM-4).

### 3.4 Elastic variables in the QP

If the linearized rows are infeasible (ALG-7), each nonlinear row `i` gets elastics `v_i, w_i >= 0` and its equality becomes `F_i + J_i d - s_i + v_i - w_i = 0`, with `gamma (v_i + w_i)` added to the objective. The QP is then always feasible. `gamma` starts at `elastic_weight` and grows by a fixed factor, up to a cap, each time the elastic solution still violates the true constraints; if the infeasibility cannot be driven to zero the solve ends with 13 or 14.

## 4. Merit function and line search

### 4.1 Augmented Lagrangian merit

```text
M(x, s, pi) = f(x) - pi'(F(x) - s) + 1/2 (F(x) - s)' D (F(x) - s)
```

over the nonlinear rows only, with `D = diag(rho_i)`, `rho_i >= 0` (ALG-5). The search direction is the combined `(d_x, d_s, d_pi)` with `d_pi = pi_hat - pi_k`, so `pi` moves toward the QP multipliers at the same rate as `x`. GMS show the QP step is a descent direction for `M` once `D` is large enough; the update rule raises only those `rho_i` needed to make `M'(0) <= -1/2 d' H d` (a fixed fraction of the QP's predicted decrease) and lets them decay slowly afterward to avoid ill-conditioning, following Gill, Murray, Saunders, and Wright (1992).

### 4.2 Step selection

A safeguarded polynomial search (quadratic, then cubic) on `phi(alpha) = M(x + alpha d_x, s + alpha d_s, pi + alpha d_pi)` seeks a step with `phi(alpha) <= phi(0) + mu alpha phi'(0)` for a small `mu` (1e-4) and `|phi'(alpha)| <= eta |phi'(0)|` with `eta = linesearch_tolerance` (0.9 is loose, 0.1 nearly exact). The first trial step is `min(1, major_step_limit (1 + ||x||) / ||d_x||)`. When the callback returns `error.Undefined` at a trial point the step is halved and retried until a floor triggers exit 63 (PRB-8). When no step gives sufficient decrease and the Hessian has already been reset, exit 41. This is SNOPT's `srchq`/`srchc` pair in spirit: derivative-free when `G` is expensive relative to `f`, derivative-based when they come together.

## 5. Quasi-Newton Hessian

`H` approximates the Hessian of the Lagrangian `L = f - pi'F` with respect to the nonlinear variables only (ALG-6). After a step with `delta = x_{k+1} - x_k` (nonlinear part) and `y = grad L(x_{k+1}, pi_{k+1}) - grad L(x_k, pi_{k+1})`, the BFGS update applies when `y' delta >= sigma delta' H delta` for a small `sigma` (positive curvature). Otherwise, GMS try a modified `y` that adds the augmented-Lagrangian term `J' D (F_{k+1} - F_k)`, and skip the update if that still fails; repeated skips trigger a reset to a scaled identity.

**Limited memory (default).** `H = H_0 + sum over stored pairs of (v_j v_j' - u_j u_j')`, with `H_0 = sigma_0 I` self-scaled and `hessian_updates` pairs; after that many updates the memory is flushed and `H_0` rescaled. Products `H v` cost `O(n_nonlinear * pairs)`; the QP needs `Z'HZ` only through such products as `R` is built column by column, which is why `R` and not `H` is the factor that is kept.

**Full memory.** For small `n`, keep `H` as a dense Cholesky factor and apply the rank-two BFGS update as two rank-one updates. The truss and HS tests have `n <= 5`, so this mode is the simpler first target; limited memory is required for the "sparse, large" goal.

## 6. Infeasibility handling summary

| Situation | Response | Exit if hopeless |
| --- | --- | --- |
| Bounds and linear rows inconsistent | Feasibility phase fails | 11 or 12 |
| Linearized rows infeasible at a major iteration | Enter elastic mode (section 3.4) | 13, 14, or 15 |
| Nonlinear violation beyond `violation_limit` | Stop | 22 |
| Objective decreasing without bound | Stop | 21 |

## 7. Convergence tests

Following the SNOPT manual (ALG-8):

- **Primal.** `max_i viol_i / (1 + ||x||_inf) <= major_feasibility_tolerance`, where `viol_i` is the violation of nonlinear row `i` against `[f_low_i, f_upp_i]`. Linear rows and bounds are already within `minor_feasibility_tolerance` by construction.
- **Dual.** `max_j comp_j / max(1, ||pi||) <= major_optimality_tolerance`, where `comp_j` is the complementarity of variable or slack `j`: `sigma_j min(x_j - l_j, 1)` at a lower bound, `-sigma_j min(u_j - x_j, 1)` at an upper bound, `|sigma_j|` when free, with `sigma` the reduced costs from the current multipliers and `||pi||` a scaled 2-norm as in SNOPT.

`Result.primal_infeasibility` and `dual_infeasibility` report these two quantities at exit. The tests in `test/` assert unscaled quantities on `State`, so the truss problem's `1e8` rows force the implementation to get scaling right rather than to loosen tolerances.

## 8. Derivatives

- **Verification (ALG-12).** At the first linearly feasible point, compare each `G` entry with a forward or central difference of `f`; also difference every column and flag any `(row, col)` outside `A` and `G` with a nonzero difference, since that is either a missing pattern entry or a linear term wrongly included in `f`. `test/support.zig` carries an independent implementation of this check; the solver's own version must agree with it.
- **Missing derivatives (ALG-11, NUM-7).** With `derivative_option == .some_missing`, `g` is pre-filled with NaN; entries still NaN after the call are estimated column by column with forward differences `h_j = difference_interval (1 + |x_j|)`, switching to central differences once the optimality measure approaches the noise level implied by `function_precision`. Columns with disjoint row patterns share one evaluation (Curtis, Powell, and Reid 1974).
- **Pattern estimation (ALG-13).** Estimate `J` at several perturbed points near `x0`; entries identical across points to within `function_precision` are constant (go to `A`), entries that vary are nonlinear (go to `G`), zeros are dropped. Same idea as `snJac`.

## 9. Linear algebra plan

| Object | First implementation | Eventual | SIMD |
| --- | --- | --- | --- |
| Basis `B` (`m x m`) | Dense LU with partial pivoting; refactor after a fixed number of updates; row-replacement updates | Sparse LU (LUSOL: Markowitz ordering, threshold partial pivoting, Bartels-Golub or Forrest-Tomlin updates) | Row axpy in elimination and updates |
| Reduced-Hessian factor `R` (`nS x nS`) | Dense upper triangular; column add via an `R'` solve; column delete via a Givens sweep; rank-one BFGS update via Givens | Same (SQOPT keeps this dense too) | Triangular solves; rotation application across rows |
| `H` products | Dense full-memory `H` for small `n`; limited-memory pair sums | Same | Dot and axpy over the nonlinear variables |
| Sparse `[A ; G]` | CSC with a pattern-order permutation for scattering callback `G` values (NUM-3) | Same | FMA over contiguous value runs in both products |
| Dense vectors | `@Vector(w, f64)` kernels (NUM-2) | Same | Everything |

A dense `B` caps the practical problem size at a few thousand rows (`m^2` doubles of memory, `O(m^3)` per factorization). The interface between the QP solver and the basis factor is designed so that a sparse LU is a drop-in (NUM-5).

## 10. Notes on the acceptance problem

The three-bar truss (`example.md`) is small but hostile: variables of `1e-4`, rows of `1e8`, Jacobian entries of `1e12`, a multiplier of `1e-8`. Unscaled, the dual test asks `grad f` (of order `1e4`) to be cancelled by `J' pi` to about `1e-6` absolute, a relative `1e-10`: achievable for a two-variable QP solved exactly, but only if the merit function, penalty updates, and Hessian scaling do not amplify round-off. The closed form (`example.md` section 7) has the single active row `sigma3 = -sigma_allow`, so once the active set is identified one exact QP step lands on the constraint curve and the remaining iterations are Newton-like along it. A correct implementation should converge in well under 20 major iterations from `x0 = (5e-4, 5e-4)`; the test asserts optimality only, not the count.

## 11. References

1. P. E. Gill, W. Murray, M. A. Saunders. *SNOPT: An SQP algorithm for large-scale constrained optimization.* SIAM Review 47(1), 99-131, 2005. The primary design reference.
2. P. E. Gill, W. Murray, M. A. Saunders, E. Wong. *User's Guide for SNOPT 7.7: Software for Large-Scale Nonlinear Programming.* CCoM Technical Report 18-1, UC San Diego, 2018. Options, exit codes, and the snOptA interface; the test problems at <https://github.com/snopt/snopt7-examples> accompany it.
3. P. E. Gill, W. Murray, M. A. Saunders, E. Wong. *User's Guide for SQOPT 7.7: Software for Large-Scale Linear and Quadratic Programming.* 2018. The QP subproblem solver's design.
4. P. E. Gill, W. Murray, M. A. Saunders, M. H. Wright. *Procedures for optimization problems with a mixture of bounds and general linear constraints.* ACM Transactions on Mathematical Software 10(3), 282-298, 1984. Reduced-Hessian active-set methods with a dense `R`.
5. P. E. Gill, W. Murray, M. A. Saunders, M. H. Wright. *A practical anti-cycling procedure for linearly constrained optimization.* Mathematical Programming 45, 437-474, 1989. EXPAND.
6. P. E. Gill, W. Murray, M. A. Saunders, M. H. Wright. *Some theoretical properties of an augmented Lagrangian merit function.* In *Advances in Optimization and Parallel Computing*, 101-128, North-Holland, 1992. Merit function and penalty updates.
7. P. E. Gill, W. Murray, M. A. Saunders, M. H. Wright. *Maintaining LU factors of a general sparse matrix.* Linear Algebra and its Applications 88/89, 239-270, 1987. LUSOL.
8. J. J. Moré, D. J. Thuente. *Line search algorithms with guaranteed sufficient decrease.* ACM Transactions on Mathematical Software 20(3), 286-307, 1994.
9. R. Fourer. *Solving staircase linear programs by the simplex method, 1: Inversion.* Mathematical Programming 23, 274-313, 1982. Geometric-mean scaling as used by MINOS and SNOPT.
10. A. R. Curtis, M. J. D. Powell, J. K. Reid. *On the estimation of sparse Jacobian matrices.* Journal of the Institute of Mathematics and its Applications 13, 117-119, 1974.
11. J. Nocedal, S. J. Wright. *Numerical Optimization*, 2nd edition. Springer, 2006. Chapters 6 (quasi-Newton), 7 (limited memory), 16 (QP), 18 (SQP).
12. W. Hock, K. Schittkowski. *Test Examples for Nonlinear Programming Codes.* Lecture Notes in Economics and Mathematical Systems 187, Springer, 1981. Problems 15, 47, 76, 118.
