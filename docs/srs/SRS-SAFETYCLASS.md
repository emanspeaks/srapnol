---
active: true
derived: false
level: 5.1
links: []
normative: false
ref: ''
reviewed: 6zGa66an7hPzkL8OlQDS7C4MHhVGouo_9cGtpQNZjog=
---

# Safety classification

`srapnol` performs no function whose failure can cause injury, loss of life, or
damage to equipment; it is not safety-critical under NASA-STD-8739.8, and no system
hazards trace to it. No software-related safety constraints, controls, mitigations,
or assumptions between hardware, operator, and software (NPR 7150.2D SWE-184) apply.
A host that embeds the library in a safety-critical function is responsible for its
own hazard analysis; the fault-management behavior below and in section 2.5 is what
the library offers such a host.