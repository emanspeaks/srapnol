---
active: true
derived: false
level: 1.2
links: []
normative: false
ref: ''
reviewed: UhrBqJKTUkxu22v_T69c12bgW_kTP1XRchMAPmIDmjM=
---

# Conventions

Automated procedures are Zig tests compiled into the module's test binary and run with
`zig build test`; each procedure lists the Zig test names it comprises. A procedure's
`status` is `done` when its tests exist and pass, `surface` when the tests exist but
skip because the solver is a stub, and `pending` when the tests are not yet written.
Inspection and demonstration procedures state their steps explicitly.