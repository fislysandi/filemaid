# Filemaid

Filemaid is a programmable filesystem automation engine written in Common Lisp.

## Core Pipeline

`filesystem -> scanner -> filters -> rules -> actions`

## Rule DSL Example

```lisp
(rule invoices
  (from "~/Downloads")
  (when (and (extension "pdf")
             (pdf-contains "invoice")))
  (move "~/Documents/Invoices"))
```

## Commands

```bash
filemaid run rules/example-rules.lisp
filemaid scan ~/Downloads
filemaid preview rules/example-rules.lisp
filemaid init-project --template invoice-template --name my-filemaid-project
filemaid init-project --template rules/example-rules.lisp --target ./my-custom-folder --template-name org-rules
filemaid explain-conflicts rules/example-rules.lisp --diagnostics-format json
filemaid conflict-profile list
filemaid watch ~/Downloads --backend auto --interval 2 --iterations 5 --verbose
```

## Runtime Flags

- `run`: `--dry-run`, `--verbose`, `--no-rollback`, `--yes`, `--conflict-policy`, `--file-conflict-policy`, `--per-conflict`, `--diagnostics-format text|json`
- `preview`: always dry-run, optional `--verbose`, `--conflict-policy`, `--file-conflict-policy`, `--diagnostics-format text|json`
- `init-project`: `--template <name-or-path>`, optional `--template-name NAME`, `--target DIR`, `--name PROJECT`, `--verbose`
- `explain-conflicts`: analyze rules and report conflicts without applying changes (exit `0` no conflicts, `2` conflicts found)
- `conflict-profile`: manage saved per-conflict decisions (`list`, `remove <key|index>`, `clear`)
- `scan`: optional `--recursive`
- `watch`: `--backend auto|poll|inotify`, `--interval N`, `--iterations N`, `--recursive`, `--verbose`

## Project Initialization

- `init-project` creates standard folder structure (`src/`, `rules/`, `tests/`, `python/`, `.opencode/context/`).
- Default project root is `~/.config/filemaid/projects/<project-name>/` when `--target` is not provided.
- Template lookup supports:
  - direct file paths (with or without `.lisp` extension), and
  - named templates from `~/.config/filemaid/projects/templates/`.
- `--template-name` controls output filename under `rules/` (defaults to `organization-rules.lisp`).
- `--name` controls default folder name when `--target` is omitted.

## Conflict Resolution

- Filemaid resolves conflicting actions before execution.
- Policies: `error-on-conflict` (default), `skip-on-conflict`, `first-wins`, `last-wins`, `priority`.
- Set globally in config with `*conflict-policy*` or per command via `--conflict-policy`.
- File conflict policies (destination exists): `error` (default), `overwrite`, `skip`, `rename`.
- Set globally with `*file-conflict-policy*` or per command via `--file-conflict-policy`.
- In `--verbose` mode, CLI prints conflict diagnostics showing dropped/replaced intents.
- Diagnostics can be emitted as JSON with `--diagnostics-format json`.
- Runtime execution safety enables rollback by default for rollback-capable actions; use `--no-rollback` to disable.
- In non-automated mode, `run` previews planned filesystem changes and asks for confirmation before execution.
- In non-automated mode, detected conflicts are listed up front and Filemaid prompts for conflict policy before preview/apply.
- With `--per-conflict`, Filemaid prompts per conflict pair (left/right/skip/policy fallback) before final preview.
- Per-conflict decisions are persisted to `~/.config/filemaid/conflict-resolution.sexp` and reused automatically.
- Use `filemaid conflict-profile list` to inspect saved decisions.
- Use `filemaid conflict-profile remove <key|index>` or `clear` to manage saved decisions.
- Use `--yes` (or `--auto-approve`) to skip interactive confirmation for automation.

Example in `~/.config/filemaid/config.lisp`:

```lisp
(in-package :filemaid)
(set-conflict-policy :priority)
(set-file-conflict-policy :rename)

;; Optional path for persisted per-conflict choices:
(setf *conflict-resolution-profile-path* #P"~/.config/filemaid/conflict-resolution.sexp")

;; Optional project defaults/customization hooks:
(setf *projects-root* #P"~/.config/filemaid/projects/")
(setf *project-templates-root* #P"~/.config/filemaid/projects/templates/")
(setf *init-project-target-resolver*
      (lambda (template-spec project-name target-option)
        (declare (ignore template-spec project-name))
        (if target-option
            (uiop:ensure-directory-pathname target-option)
            (merge-pathnames "custom-default/"
                             (projects-root-pathname)))))
```

## Default Config

- On every CLI invocation, Filemaid tries to load `~/.config/filemaid/config.lisp`.
- If missing, execution continues normally.
- Use this file for local defaults and reusable rule helpers.

## Optional Python Bridge

- Enable with environment variable: `FILEMAID_ENABLE_PYTHON=1`
- Python remains an optional helper layer; core logic stays in Lisp.

## Development

- Primary implementation target: SBCL
- Dependency strategy: OCICL-managed dependencies
- Test entrypoint: `asdf:test-system "filemaid"`

## Project Layout

```text
filemaid/
|-- filemaid.asd
|-- ocicl.lisp
|-- src/
|   |-- package.lisp
|   |-- config.lisp
|   |-- cli.lisp
|   |-- scanner.lisp
|   |-- pipeline.lisp
|   |-- rules.lisp
|   |-- filters.lisp
|   |-- actions.lisp
|   `-- python-bridge.lisp
|-- rules/example-rules.lisp
|-- tests/core-tests.lisp
|-- tests/dsl-tests.lisp
|-- tests/cli-tests.lisp
|-- tests/integration-tests.lisp
`-- python/metadata.py
```
