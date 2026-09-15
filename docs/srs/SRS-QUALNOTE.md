---
active: true
derived: false
level: 11.1
links: []
normative: false
ref: ''
reviewed: nwL-v5Xrn6g9ZwNzKEd3Xrq9F9hkRBMPGvybicjztJk=
---

# Verification methods and acceptance

Each normative item names its method in `verification-method`. Test items are
verified by the procedures in TST, which link back to the items they verify; the
Software Test Plan defines levels, environment, and the acceptance rule (every
non-skipped procedure passes; a procedure may skip only while every item it verifies
has `status: pending`). Inspection and Analysis items are verified by peer review
against the Software Design Description and the source, recorded as described in the
Software Development/Management Plan. Demonstration items are verified by running the
build or the program and recording the observation in a Software Test Report.