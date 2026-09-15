# Interface Design Description: C application binary interface

| Field | Value |
| --- | --- |
| Identifier | SRAPNOL-IDD |
| Revision | 0.1 (draft; interface planned for phase 9, not yet implemented) |
| Date | 2026-09-15 |
| Interfacing entities | `srapnol` (Zig) and any C-ABI host (C, C++, Fortran, Python ctypes, MATLAB, Julia, ...) |
| Prepared by | Randy Eckman, maintainer |

Content follows NASA-HDBK-2203 topic 5.02. The Zig-native interface is described in the
SUM; this document specifies the shared-library interface that satisfies SRS section
3.2 and section 10. Types and units of every element are in the Software Data
Dictionary.

## Revision history

| Revision | Date | Description |
| --- | --- | --- |
| 0.1 | 2026-09-15 | Initial specification of the planned interface. |

## 1. Interface identification

| Field | Value |
| --- | --- |
| Name | `srapnol` C ABI, header `srapnol.h`, library `srapnol` (`srapnol.dll`, `libsrapnol.so`, `libsrapnol.dylib`) |
| Priority | Primary interface for non-Zig hosts; the Zig interface remains authoritative |
| Type | Synchronous in-process function calls; storage-and-retrieval of arrays owned by the host |
| Direction | Host calls the library; the library calls back into the host for evaluations |
| Versioning | `srapnol_abi_version()` returns `MAJOR * 10000 + MINOR * 100 + PATCH`; a MAJOR change may break the ABI, MINOR and PATCH may only add functions |

## 2. Data elements

All floating-point data is IEEE 754 binary64 (`double`); all sizes and indices are
`uint32_t`, 0-based; all enumerations are `int32_t`. Arrays are contiguous, host-owned,
and passed as pointer plus length; the library never frees host memory and never
retains a pointer beyond the call that received it, except the problem arrays, which
must stay valid while the `srapnol_problem` handle exists.

### 2.1 Opaque handles

| Handle | Created by | Destroyed by | Represents |
| --- | --- | --- | --- |
| `srapnol_problem*` | `srapnol_problem_create` | `srapnol_problem_destroy` | `Problem` |
| `srapnol_solver*` | `srapnol_solver_init` | `srapnol_solver_deinit` | `Solver` and its workspace |
| `srapnol_state*` | `srapnol_state_create` | `srapnol_state_destroy` | `State` |

### 2.2 Structures

```c
typedef struct srapnol_request {
    const double *x;      /* length n */
    double *f;            /* length nf, or NULL when f is not needed */
    double *g;            /* length ng, or NULL when G is not needed */
    int32_t status;       /* SRAPNOL_STATUS_FIRST | NORMAL | LAST */
} srapnol_request;

typedef struct srapnol_response {
    int32_t reserved;     /* zero; future use */
} srapnol_response;

typedef int32_t (*srapnol_eval_fn)(void *ctx, const srapnol_request *req,
                                   srapnol_response *resp);

typedef struct srapnol_options {
    uint32_t size;        /* sizeof(srapnol_options), set by the host */
    /* one field per Options field, same names, same defaults; see data dictionary */
    uint32_t major_iterations_limit;
    uint32_t minor_iterations_limit;
    uint32_t iterations_limit;
    double major_feasibility_tolerance;
    double major_optimality_tolerance;
    double minor_feasibility_tolerance;
    int32_t derivative_option;
    int32_t verify_level;
    int32_t hessian;
    uint32_t hessian_updates;
    double elastic_weight;
    double infinite_bound;
    int32_t scale_option;
    double function_precision;
    double difference_interval;
    double central_difference_interval;
    double linesearch_tolerance;
    double major_step_limit;
    double penalty_parameter;
    uint32_t superbasics_limit;   /* 0 means min(500, n + 1) */
    double unbounded_objective;
    double unbounded_step_size;
    double violation_limit;
    uint32_t major_print_level;
    uint32_t minor_print_level;
    srapnol_write_fn writer;      /* NULL for silence */
    void *writer_ctx;
} srapnol_options;

typedef int32_t (*srapnol_write_fn)(void *ctx, const char *bytes, size_t len);

typedef struct srapnol_result {
    int32_t exit;                 /* snOptA INFO code */
    double objective;
    uint32_t major_iterations;
    uint32_t minor_iterations;
    uint32_t function_evaluations;
    uint32_t jacobian_evaluations;
    uint32_t num_infeasibilities;
    double sum_infeasibilities;
    uint32_t superbasics;
    double primal_infeasibility;
    double dual_infeasibility;
} srapnol_result;
```

`srapnol_options_default(srapnol_options *opts)` fills SNOPT defaults; the `size` field
lets a newer library accept an older host structure.

### 2.3 Data element assemblies

| Assembly | Elements | Notes |
| --- | --- | --- |
| Bounds | `x_low[n]`, `x_upp[n]`, `f_low[nf]`, `f_upp[nf]` | magnitude at or above `infinite_bound` means no bound |
| Linear part `A` | `a_rows[na]`, `a_cols[na]`, `a_vals[na]` | any order; no duplicate slot |
| Pattern `G` | `g_rows[ng]`, `g_cols[ng]` | any order; disjoint from `A` slots |
| State | `x[n]`, `x_state[n]`, `x_mul[n]`, `f[nf]`, `f_state[nf]`, `f_mul[nf]` | read through `srapnol_state_*` accessors; states are the snOptA integers |

## 3. Functions

| Function | Returns | Description |
| --- | --- | --- |
| `int32_t srapnol_abi_version(void)` | version | See section 1 |
| `srapnol_problem *srapnol_problem_create(uint32_t n, uint32_t nf, int32_t obj_row, double obj_add, const double *x_low, const double *x_upp, const double *f_low, const double *f_upp, uint32_t na, const uint32_t *a_rows, const uint32_t *a_cols, const double *a_vals, uint32_t ng, const uint32_t *g_rows, const uint32_t *g_cols, srapnol_eval_fn eval, void *ctx, const char *name)` | handle or NULL | `obj_row < 0` means feasible-point mode; arrays are borrowed; validation happens in `srapnol_solver_init` |
| `void srapnol_problem_destroy(srapnol_problem *)` | | Frees the handle only |
| `int32_t srapnol_validate(const srapnol_problem *)` | 0 or error code | The SRS validation checks, without creating a solver |
| `void srapnol_options_default(srapnol_options *)` | | SNOPT defaults |
| `int32_t srapnol_solver_init(const srapnol_problem *, const srapnol_options *, srapnol_alloc_fn alloc, srapnol_free_fn free, void *alloc_ctx, srapnol_solver **out)` | 0 or error code | Validates, allocates the workspace through the host allocator (NULL selects the C library allocator) |
| `void srapnol_solver_deinit(srapnol_solver *)` | | Frees the workspace |
| `int32_t srapnol_state_create(const srapnol_problem *, const double *x0, srapnol_alloc_fn, srapnol_free_fn, void *, srapnol_state **out)` | 0 or error code | Copies `x0`, zeroes the rest |
| `void srapnol_state_destroy(srapnol_state *)` | | |
| `int32_t srapnol_solve(srapnol_solver *, srapnol_state *, int32_t start, srapnol_result *out)` | 0 or error code | `start`: `SRAPNOL_START_COLD`, `BASIS`, `WARM`; algorithmic outcomes are in `out->exit` with return 0 |
| `const double *srapnol_state_x(const srapnol_state *, uint32_t *len)` and likewise `_x_mul`, `_f`, `_f_mul` | pointer into the state | Valid until the state is destroyed |
| `const int32_t *srapnol_state_x_state(const srapnol_state *, uint32_t *len)` and `_f_state` | pointer | snOptA state integers |
| `int32_t srapnol_state_set(srapnol_state *, const double *x, const int32_t *x_state, const double *x_mul, const int32_t *f_state, const double *f_mul)` | 0 or error code | Any argument may be NULL to leave that array unchanged; used before `BASIS`/`WARM` starts |
| `const char *srapnol_strerror(int32_t code)` | static string | Name of an error code or exit code |

## 4. Return and exit codes

Return value 0 means the call succeeded. Negative values are interface errors:

| Code | Name | Meaning |
| --- | --- | --- |
| -1 | `SRAPNOL_E_INVALID_ARGUMENT` | NULL handle or pointer, bad enumeration, inconsistent length |
| -2 | `SRAPNOL_E_OUT_OF_MEMORY` | Host allocator failed |
| -3 | `SRAPNOL_E_INVALID_OPTION` | `error.InvalidOption` |
| -10 .. -19 | `SRAPNOL_E_VALIDATE_*` | One per `Problem.ValidateError` member, in declaration order |
| -100 | `SRAPNOL_E_NOT_IMPLEMENTED` | Stub (pre-release only) |

Callback return values: 0 success; `SRAPNOL_CB_UNDEFINED` (-1) maps to
`error.Undefined`; `SRAPNOL_CB_ABORT` (-2) maps to `error.Abort`; any other nonzero
value is treated as abort.

Exit codes in `srapnol_result.exit` are the snOptA `INFO` codes listed in the SUM,
unchanged.

## 5. Communication method and protocol

In-process function calls with the platform C calling convention (`callconv(.c)`);
no threads are created; a solver handle must not be used concurrently from two
threads, but distinct handles may. The callback is invoked on the caller's thread with
`status` sequencing as in the SUM (`FIRST` once, `NORMAL`, `LAST` once with `f` and
`g` NULL). Diagnostic output goes to `writer` in chunks of at most one line.

## 6. Physical compatibility

Shared library built by `zig build shim` for the target triple; exports only
`srapnol_*` symbols; no libc dependency beyond the platform loader; header is C99 and
usable from C++ (`extern "C"` guard included).

## 7. Interface compatibility

Adding fields to `srapnol_options` or `srapnol_result` bumps MINOR and keeps old
layouts valid through the `size` field (options) or by appending only (result).
Removing or reordering anything bumps MAJOR. Exit and error codes never change meaning.

## 8. Safety

Not safety-critical. The shim validates every pointer, length, and enumeration and
returns an error code rather than dereferencing invalid input; it never terminates the
host process.

## 9. Traceability

| Interface element | SRS |
| --- | --- |
| Handles, functions, structures | C-callable interface (section 3.2) |
| Adapter over the Zig API, no policy change | C interface is an adapter (3.2) |
| `srapnol_eval_fn` and callback codes | C callback convention (3.2) |
| Return and exit codes | C error and exit codes (3.2) |
| Validation of inputs | C input validation (3.2) |
| `zig build shim`, exports, header, no libc | Shared library build step, no C runtime dependency (section 10) |
| Determinism, allocation, threading | Sections 4, 6, 7 |
