---
active: true
derived: false
level: 3.4.1
links: []
normative: false
ref: ''
reviewed: MdhLzNXCAI1rX1PoT4foWrv1zkHd8p0uyTFzkXPlLrA=
---

# External software interfaces

The library interfaces with: the Zig standard library; the `rstd` package (build
utilities now, `rstd.linalg` kernels at integration); the host's evaluation callback
(section 2.3); the host's allocator (section 3.1); and an optional `std.Io.Writer`
for diagnostics (section 3.3). There are no hardware, network, file, or user
interfaces. The C shim (section 3.2) is the only interface intended for non-Zig hosts;
its data elements are defined in the IDD.