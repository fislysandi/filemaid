# Filemaid Context7

## What This Project Is

Filemaid is a programmable filesystem automation engine written in Common Lisp.
It scans files, evaluates Lisp DSL rules, and executes actions such as move,
copy, rename, delete, and tag.

## Core Design Goals

- Functional-first architecture with explicit inputs/outputs.
- Macro-based DSL with readable expansion and stable user syntax.
- Reproducible builds on SBCL with OCICL-managed dependencies.
- Safe execution with dry-run preview, conflict resolution, and rollback hooks.

## Processing Pipeline

filesystem -> scanner -> filters -> rules -> actions

Module direction is enforced:

CLI -> Rules DSL -> Pipeline -> Filters/Actions -> Scanner -> Filesystem

## Rule DSL Example

```lisp
(rule invoices
  (from "~/Downloads")
  (when (and (extension "pdf")
             (pdf-contains "invoice")))
  (move "~/Documents/Invoices"))
```

## Key Runtime Features

- Conflict policy control: error/skip/first/last/priority.
- File-conflict policy control: error/overwrite/skip/rename.
- Interactive non-automated mode:
  - upfront conflict inspection,
  - optional per-conflict decision,
  - plan preview,
  - confirmation before apply.
- Diagnostics output in text or JSON.

## Project Structure (Main)

- `src/` core implementation modules.
- `rules/` rule templates and examples.
- `tests/` unit/integration tests.
- `.opencode/context/filemaid/` agent-facing context system.

## Important Commands

- `filemaid preview <rules-file>`
- `filemaid run <rules-file>`
- `filemaid explain-conflicts <rules-file>`
- `filemaid init-project --template <name-or-path>`

## Config Defaults

- `~/.config/filemaid/config.lisp`
- Projects root: `~/.config/filemaid/projects/`
- Template root: `~/.config/filemaid/projects/templates/`
- Conflict profile: `~/.config/filemaid/conflict-resolution.sexp`
