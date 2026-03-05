<!-- Context: filemaid/guides | Priority: high | Version: 1.0 | Updated: 2026-03-05 -->
# Guide: CL-TRON Workflow

**Purpose**: Standardize agent workflow around cl-tron-mcp for Lisp-first development, debugging, and validation.
**Last Updated**: 2026-03-05

## Prerequisites
- cl-tron-mcp health check passes.
- SWANK REPL connection is active.
- `filemaid.asd` is available from repository root.

**Estimated time**: 5-10 min per iteration

## Required Workflow
1. Run cl-tron health check before edits.
2. Use cl-tron REPL for quick expression checks and macro expansion.
3. Validate system load under SBCL after edits.
4. Run `asdf:test-system` before finalizing changes.

## Macro Validation Pattern
```lisp
(macroexpand-1
 '(rule invoices
    (from "~/Downloads")
    (when (extension "pdf"))
    (move "~/Documents/Invoices")))
```

## Runtime Validation Pattern
```lisp
(asdf:load-system "filemaid")
(asdf:test-system "filemaid")
```

## 📂 Codebase References

**Entry and Build**:
- `filemaid.asd` - system and test definitions.

**DSL and Pipeline**:
- `src/rules.lisp` - macro expansion targets.
- `src/pipeline.lisp` - runtime orchestration path.

**Tests**:
- `tests/core-tests.lisp` - post-edit verification suite.

## Related
- guides/rule-dsl-design.md
- guides/testing-guidelines.md
