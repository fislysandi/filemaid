# Filemaid

Filemaid is a programmable filesystem automation engine written in Common Lisp, Think of it as IFTTT for your file system - define patters, and filemaid moves, tags, or transforms files automatically when they appear in monitored directories.

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
filemaid run --rules rules/example-rules.lisp --yes
filemaid run organization-rules.lisp --yes
filemaid scan ~/Downloads
filemaid preview rules/example-rules.lisp
filemaid preview --rules rules/example-rules.lisp
filemaid preview organization-rules.lisp
filemaid preview
filemaid init-project --template invoice-template --name my-filemaid-project
filemaid init-project --template rules/example-rules.lisp --target ./my-custom-folder --template-name org-rules
filemaid template list
filemaid fs
filemaid explain-conflicts rules/example-rules.lisp --diagnostics-format json
filemaid conflict-profile list
filemaid preview examples/documents-rules.lisp
filemaid conflict-profile export ./profile.sexp
filemaid conflict-profile import ./profile.sexp
filemaid watch ~/Downloads --backend auto --interval 2 --iterations 5 --verbose
```

## Runtime Flags

- `run`: `--dry-run`, `--verbose`, `--no-rollback`, `--yes`, `--conflict-policy`, `--file-conflict-policy`, `--per-conflict`, `--diagnostics-format text|json`
- `run`: supports positional rules arg and `--rules <path>`
- `run`: supports short file names (e.g. `organization-rules.lisp`) with project/global lookup
- `preview`: always dry-run; rules file is optional and falls back to configured/default project rules
- `preview`: supports positional rules arg and `--rules <path>`
- `preview`: supports short file names (e.g. `organization-rules.lisp`) with project/global lookup
- `init-project`: `--template <name-or-path>`, optional `--template-name NAME`, `--target DIR`, `--name PROJECT`, `--verbose`
- `template`: `list` available templates from configured templates root
- `fs`: show filesystem-style overview of configured projects/rules/templates/addons
- `explain-conflicts`: analyze rules and report conflicts without applying changes (exit `0` no conflicts, `2` conflicts found)
- `conflict-profile`: manage saved per-conflict decisions (`list`, `remove <key|index>`, `clear`, `export <path>`, `import <path> [--replace]`)
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

## Default Rules Resolution

When you run `filemaid preview` (or `filemaid run`) with no rules argument, Filemaid resolves rules in this order:

1. nearest project root from current working directory (`filemaid.asd` or `rules/organization-rules.lisp`), then:
   - `<project-root>/rules/organization-rules.lisp`
   - `<project-root>/rules/example-rules.lisp`
2. first existing path in `*default-rules-files*`
3. `~/.config/filemaid/projects/<*default-project-name*>/rules/organization-rules.lisp` (when set)
4. `~/.config/filemaid/rules/organization-rules.lisp`
5. `~/.config/filemaid/rules/example-rules.lisp`
6. first discovered `~/.config/filemaid/rules/*.lisp`
7. `./rules/organization-rules.lisp`
8. `./rules/example-rules.lisp`
9. first discovered `~/.config/filemaid/projects/*/rules/organization-rules.lisp`

## Addons

- Filemaid creates/uses `~/.config/filemaid/addons/` for extension modules.
- Addons are loaded at startup when `*autoload-addons*` is true (default).
- By default, all `*.lisp` files in addons root are loaded.
- Use `*enabled-addons*` to whitelist addon names or paths.

## Example Rules

- Example rule sets are available in `examples/`.
- Start with `examples/documents-rules.lisp` for basic organization.
- See `examples/README.md` for usage and scenario details.

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
- Use `filemaid conflict-profile export` and `import` to share/reuse decision profiles.
- Use `--yes` (or `--auto-approve`) to skip interactive confirmation for automation.

Example in `~/.config/filemaid/config.lisp`:

```lisp
(in-package :filemaid)
(set-conflict-policy :priority)
(set-file-conflict-policy :rename)

;; Optional addons config:
(setf *autoload-addons* t)
(setf *addons-root* #P"~/.config/filemaid/addons/")
;; (setf *enabled-addons* '("my-addon" "extra-rules.lisp"))

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

## Build Documentation Bundle

Create a local docs bundle (README, CONTEXT7, and Filemaid context files):

```bash
./scripts/build-docs.sh
```

Custom output path:

```bash
./scripts/build-docs.sh /tmp/filemaid-docs
```

## Build Binary

Build an executable in `build/filemaid`:

```bash
./scripts/build-binary.sh
```

Custom output location:

```bash
./scripts/build-binary.sh /tmp/filemaid-build /tmp/filemaid-build/filemaid
```

## Install Binary to ~/.local/bin

Install directly to `~/.local/bin/filemaid`:

```bash
./scripts/install-local.sh
```

If needed, add to PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

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
