<!-- Context: filemaid/guides | Priority: critical | Version: 1.0 | Updated: 2026-03-05 -->
# Guide: Rule DSL Design

**Purpose**: Define how to evolve Filemaid's Lisp rule DSL safely, predictably, and backward-compatibly.
**Last Updated**: 2026-03-05

## Prerequisites
- Read `concepts/architecture.md`.
- Understand existing rule surface and user-facing syntax.

**Estimated time**: 15 min

## DSL Principles
- DSL remains user-facing Lisp forms, not external config formats.
- Macros enforce compile-time structure and normalize rule forms.
- Runtime behavior stays explicit in generated function code.
- DSL changes preserve backward compatibility unless explicitly versioned.

## Macro Usage Policy
- Use macros to remove boilerplate and constrain syntax.
- Avoid macros that hide dynamic runtime side effects.
- Keep expansion output inspectable via `(macroexpand ...)`.
- Document expansion contracts for all user-facing macros.

## Recommended Shape
```lisp
(rule invoices
  (from "~/Downloads")
  (when (and (extension "pdf")
             (pdf-contains "invoice")))
  (move "~/Documents/Invoices"))
```

## Implementation Guidance
1. Parse/validate macro arguments at expansion time.
2. Expand into function-centric internal representation.
3. Route execution through pipeline and actions modules.
4. Keep predicate/action symbols composable and testable.

## Verification
- `macroexpand` shows readable expansion output.
- Expanded code routes through pipeline without circular dependencies.
- Existing rule files continue to run unchanged.

## 📂 Codebase References

**DSL Surface**:
- `src/rules.lisp` - macro definitions and rule assembly.
- `rules/example-rules.lisp` - canonical user rule examples.

**Execution Path**:
- `src/pipeline.lisp` - rule evaluation integration.
- `src/actions.lisp` - execution effects after rule match.

**Tests**:
- `tests/core-tests.lisp` - DSL behavior and compatibility checks.

## Related
- concepts/architecture.md
- guides/coding-standards.md
- guides/testing-guidelines.md
