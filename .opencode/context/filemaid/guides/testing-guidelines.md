<!-- Context: filemaid/guides | Priority: high | Version: 1.0 | Updated: 2026-03-05 -->
# Guide: Testing Guidelines

**Purpose**: Define practical testing strategy for Filemaid's functional core, DSL behavior, and side-effect boundaries.
**Last Updated**: 2026-03-05

## Prerequisites
- Basic Common Lisp testing workflow.
- Familiarity with scanner, filters, rules, and actions layers.

**Estimated time**: 10 min

## Testing Priorities
- Critical: rules evaluation, pipeline composition, action safety.
- High: CLI behavior and dry-run/preview semantics.
- Medium: optional integrations (Python bridge wrappers).

## Required Coverage
- Happy path for each pipeline stage.
- Edge cases (empty directories, unknown extensions, no matches).
- Error paths (invalid rule forms, permission failures, malformed input).
- Regression tests for DSL compatibility.

## Test Design Rules
- Prefer deterministic tests using controlled fixtures.
- Separate pure function tests from side-effect integration tests.
- Validate dry-run mode causes zero filesystem mutations.
- Test preview and verbose outputs for expected intent signals.

## Quick Example
```lisp
;; Arrange file-object fixtures, Act pipeline execution, Assert selected actions.
```

## 📂 Codebase References

**Test Suites**:
- `tests/core-tests.lisp` - unit and integration tests.

**Code Under Test**:
- `src/pipeline.lisp` - orchestration behavior.
- `src/rules.lisp` - DSL parsing and evaluation.
- `src/actions.lisp` - effect execution and dry-run handling.
- `src/cli.lisp` - command behavior and output modes.

## Verification
- Tests pass under SBCL.
- Dry-run assertions prove no side-effect writes.
- New DSL syntax has tests for expansion and runtime behavior.

## Related
- guides/coding-standards.md
- guides/rule-dsl-design.md
