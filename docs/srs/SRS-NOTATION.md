---
active: true
derived: false
level: 1.4
links: []
normative: false
ref: ''
reviewed: gw4mLYxtH8qty1PElYkNW_Nu7Y-u3ofi3xyk2OMn_Yg=
---

# Definitions and notation

- `n` variables `x`; `nf` problem functions `F`, the objective row included.
- `F(x) = f(x) + A x`: `A` is a constant sparse matrix supplied as triplets; `f` is
  the nonlinear part evaluated by the callback; its sparse Jacobian is `G`; the full
  Jacobian is `J = G + A`.
- Slacks `s`, one per row, with `F(x) - s = 0`; multipliers `pi` for rows and bound
  multipliers for variables.
- A row is *linear* when it has no `G` entries and *nonlinear* otherwise; a variable
  is *nonlinear* when some `G` entry lies in its column.
- **shall** is mandatory; **should** is recommended; **may** is permitted. Only
  items marked normative carry requirements.
- Verification methods: Test (T) by executing the software, Analysis (A) by
  calculation or model, Inspection (I) by examining artifacts, Demonstration (D) by
  operating the software and observing.