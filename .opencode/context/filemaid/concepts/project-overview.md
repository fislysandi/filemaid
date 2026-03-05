<!-- Context: filemaid/concepts | Priority: critical | Version: 1.0 | Updated: 2026-03-05 -->
# Concept: Filemaid Project Overview

**Purpose**: Define Filemaid's mission, boundaries, and non-negotiable engineering constraints for coding agents.
**Last Updated**: 2026-03-05

## Core Idea
Filemaid is a programmable filesystem automation engine in Common Lisp. Agents must implement repository changes through a functional-first architecture, a stable Lisp DSL, and strict module boundaries.

## Key Points
- Domain: filesystem automation (scan, filter, match rules, execute actions).
- Rule authoring format is Common Lisp DSL only, not YAML/JSON.
- Core build target is SBCL with reproducible dependency resolution via OCICL.
- Architecture is pipeline-driven and composable, with explicit data flow.
- Python integration is optional and library-like only; core logic stays in Lisp.

## When to Use
- Starting new features or refactors.
- Validating whether a proposal fits repository goals.
- Aligning agent output with project-level constraints.

## Quick Example
```lisp
(rule invoices
  (from "~/Downloads")
  (when (and (extension "pdf")
             (pdf-contains "invoice")))
  (move "~/Documents/Invoices"))
```

## Agent Loading Order
1. `concepts/project-overview.md`
2. `concepts/architecture.md`
3. `guides/coding-standards.md`
4. Task-specific guide(s) in `guides/`

## 📂 Codebase References

**Project Root**:
- `filemaid.asd` - ASDF system definition.
- `ocicl.lisp` - OCICL dependency bootstrap.
- `README.md` - User and contributor entrypoint.

**Core Implementation**:
- `src/package.lisp` - Package boundaries and exports.
- `src/pipeline.lisp` - Main processing pipeline.
- `src/rules.lisp` - Rule DSL and execution integration.

**Tests**:
- `tests/core-tests.lisp` - Core behavior verification.

## Deep Dive
**Reference**: See architecture and standards docs in this context category.

## Related
- concepts/architecture.md
- guides/coding-standards.md
- guides/rule-dsl-design.md
