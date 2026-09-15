---
active: true
derived: false
level: 1.2
links: []
normative: false
ref: ''
reviewed: 8ONCZgIMU44B68EPbwsuWAyieu_oVFGqqFs4_mKoMT0=
---

# Scope

`srapnol` is a sparse, general nonlinear optimizer with an `snOptA`-style interface,
written in Zig. This document covers the Zig library, its planned C-callable shim, and
the diagnostics it emits. It does not cover the host program, the build of `rstd`, or
the numerical analysis behind the method, which is recorded in the Software Design
Description (DES).