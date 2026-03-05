<!-- Context: filemaid/concepts | Priority: critical | Version: 1.0 | Updated: 2026-03-05 -->
# Concept: Filemaid Architecture

**Purpose**: Define required module layering, data flow, and dependency boundaries for Filemaid.
**Last Updated**: 2026-03-05

## Core Idea
Filemaid uses a deterministic pipeline: filesystem -> scanner -> filters -> rules -> actions. Code must preserve one-way dependencies and prevent circular coupling.

## Key Points
- Pipeline order is fixed and must not be bypassed.
- Module dependency order is fixed: CLI -> Rules DSL -> Pipeline -> Filters/Actions -> Scanner -> Filesystem.
- Each module exposes narrow interfaces with explicit inputs/outputs.
- Filters and actions consume structured file objects.
- New features must slot into existing layers, not create cross-layer shortcuts.

## Dependency Rules
- CLI may call rules/pipeline entrypoints only.
- Rules DSL may define and compose rules, but not perform direct filesystem mutations.
- Pipeline orchestrates execution order and context passing.
- Filters evaluate predicates; actions perform effects.
- Scanner discovers file objects; filesystem layer performs low-level I/O.

## Quick Example
```text
cli.run -> load-rules -> pipeline.execute
pipeline.execute -> scanner.scan -> filters.match -> rules.select -> actions.apply
```

## Anti-Patterns
- Scanner directly invoking actions.
- Rules macros performing hidden runtime side effects.
- Cross-layer references that invert dependency direction.

## 📂 Codebase References

**Architecture Nodes**:
- `src/cli.lisp` - CLI command dispatch.
- `src/rules.lisp` - Rule definitions and expansion.
- `src/pipeline.lisp` - Pipeline coordinator.
- `src/filters.lisp` - Predicate functions.
- `src/actions.lisp` - Effectful operations.
- `src/scanner.lisp` - File discovery and object construction.

**Data Boundary**:
- `src/scanner.lisp` - `file-object` creation at scan time.

**Tests**:
- `tests/core-tests.lisp` - Layering and pipeline behavior checks.

## Deep Dive
**Reference**: `guides/coding-standards.md` for implementation constraints.

## Related
- concepts/project-overview.md
- guides/coding-standards.md
- guides/testing-guidelines.md
