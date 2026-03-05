<!-- Context: filemaid/guides | Priority: critical | Version: 1.0 | Updated: 2026-03-05 -->
# Guide: Coding Standards

**Purpose**: Provide mandatory coding rules for implementing Filemaid features safely and consistently.
**Last Updated**: 2026-03-05

## Prerequisites
- Read `concepts/project-overview.md`.
- Read `concepts/architecture.md`.
- Understand Common Lisp package organization.

**Estimated time**: 10 min

## Standards
1. Prefer pure functions and explicit data flow.
2. Avoid global mutable state and implicit side effects.
3. Keep functions focused; target <= 40 lines when practical.
4. Return values instead of mutating external state.
5. Use composition pipelines over nested mutation-heavy logic.

## Steps

### 1. Define boundaries first
```lisp
;; Define public function contracts before internals.
```
**Expected**: clear module API and data contracts.
**Implementation**: `src/package.lisp`

### 2. Implement with composable functions
```lisp
;; Compose scanner -> filters -> rules -> actions.
```
**Expected**: each function performs one task and returns explicit values.
**Implementation**: `src/pipeline.lisp`

### 3. Isolate side effects in actions/filesystem
```lisp
;; Keep I/O at the system boundary.
```
**Expected**: core transformations remain testable and deterministic.
**Implementation**: `src/actions.lisp`, `src/scanner.lisp`

### 4. Validate module direction
```text
CLI -> Rules -> Pipeline -> Filters/Actions -> Scanner -> Filesystem
```
**Expected**: no reversed or circular references.
**Implementation**: all `src/*.lisp`

## Verification
- Confirm new code respects layer direction.
- Confirm core functions are testable without filesystem writes.
- Confirm behavior is represented in `tests/core-tests.lisp`.

## 📂 Codebase References

**Module Contracts**:
- `src/package.lisp` - exports and package boundaries.

**Functional Core**:
- `src/pipeline.lisp` - composition and orchestration.
- `src/filters.lisp` - pure predicate logic.
- `src/rules.lisp` - rule representation and evaluation.

**Effectful Boundary**:
- `src/actions.lisp` - mutation and file operations.
- `src/scanner.lisp` - directory scanning and metadata read.

**Tests**:
- `tests/core-tests.lisp` - behavior-level verification.

## Troubleshooting
| Issue | Solution |
|-------|----------|
| Hidden side effects | Move effect into actions layer and return data from pure functions |
| Function too large | Split into helper functions by single responsibility |
| Circular dependency | Re-route through pipeline or shared data contracts |

## Related
- concepts/architecture.md
- guides/lisp-style-guide.md
- guides/testing-guidelines.md
