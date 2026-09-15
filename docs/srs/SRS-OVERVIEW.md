---
active: true
derived: false
level: 1.3
links: []
normative: false
ref: ''
reviewed: 3Wm_A3UBiR0b83eXmTpaf07alBhdDe7PQID4zH37UIs=
---

# System overview

The library exposes a `Problem` (dimensions, bounds, sparse structure, and an
evaluation callback), `Options` (SNOPT-compatible settings), a `Solver` that owns a
workspace sized at `init`, a caller-owned `State` (iterate, variable states,
multipliers) that is both warm-start input and solution output, and a `Result`
summarizing the run with an `Exit` code. The method is sequential quadratic
programming with an active-set, reduced-Hessian QP solver, as described in DES.