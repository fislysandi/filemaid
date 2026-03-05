<!-- Context: filemaid/guides | Priority: high | Version: 1.0 | Updated: 2026-03-05 -->
# Guide: Lisp Style Guide

**Purpose**: Define idiomatic Common Lisp conventions for readable, maintainable Filemaid code.
**Last Updated**: 2026-03-05

## Prerequisites
- Familiarity with SBCL and ASDF workflow.
- Understanding of package design and exported APIs.

**Estimated time**: 10 min

## Style Rules
- Use lowercase-hyphenated symbols and descriptive names.
- Suffix predicates with `-p`.
- Use `*earmuffed*` names for special dynamic variables.
- Keep package exports narrow and intentional.
- Add docstrings for public functions and macros.

## Macro and Function Balance
- Prefer functions first; use macros for syntax shaping only.
- Ensure macro expansions are readable and function-oriented.
- Verify expansion behavior with `(macroexpand ...)` during development.

## Conditions and Errors
- Define domain-specific conditions for expected failures.
- Use `handler-case` for boundary error handling.
- Avoid broad handlers that swallow unexpected conditions.

## Quick Example
```lisp
(defun file-extension-p (file-object extension)
  (string= (file-object-extension file-object) extension))

(defun invoice-p (file-object)
  (and (file-extension-p file-object "pdf")
       (pdf-contains-p file-object "invoice")))
```

## 📂 Codebase References

**Packages**:
- `src/package.lisp` - package definitions and exports.

**Core Code Style**:
- `src/filters.lisp` - predicate naming and pure functions.
- `src/rules.lisp` - macro/function style balance.

**Tests**:
- `tests/core-tests.lisp` - style-consistent behavior checks.

## Verification
- Public API symbols are documented and exported intentionally.
- Macro forms are inspectable and unsurprising.
- Naming and function shape align across modules.

## Related
- guides/coding-standards.md
- guides/rule-dsl-design.md
