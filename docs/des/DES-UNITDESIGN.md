---
active: true
derived: false
level: 9.1
links: []
normative: false
ref: ''
reviewed: lgQSL3-kjw7y40IKxHtZfMLbNstE3RbulVItt38d5vE=
---

# Unit-level design

Unit-level design is carried in the doc comments of each module as the implementation
phases land; each declaration that fulfils a requirement cites its SRS identifier, and
Doorstop `references` on the SRS items resolve to those citations. Algorithms are
specified above at the level needed to code and test them; parameter choices (EXPAND
frequency, refactorization interval, `mu = 1e-4`, elastic weight growth factor) are
constants in the module that owns them.