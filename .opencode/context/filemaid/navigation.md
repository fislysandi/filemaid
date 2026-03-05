<!-- Context: filemaid/lookup | Priority: critical | Version: 1.0 | Updated: 2026-03-05 -->
# Filemaid Context Navigation

**Purpose**: Route coding agents to required Filemaid context docs before any code generation.

---

## Structure

```text
filemaid/
|-- navigation.md
|-- concepts/
|   |-- project-overview.md
|   `-- architecture.md
`-- guides/
    |-- coding-standards.md
    |-- lisp-style-guide.md
    |-- rule-dsl-design.md
    |-- testing-guidelines.md
    |-- dependency-management.md
    `-- cl-tron-workflow.md
```

---

## Mandatory Loading Strategy

For any coding task in this repository, agents must load in order:
1. `concepts/project-overview.md`
2. `concepts/architecture.md`
3. `guides/coding-standards.md`
4. One or more task-specific guides:
   - DSL work -> `guides/rule-dsl-design.md`
   - Style or API work -> `guides/lisp-style-guide.md`
   - Test work -> `guides/testing-guidelines.md`
   - Dependency/integration work -> `guides/dependency-management.md`

---

## Quick Routes

| Task | Path |
|------|------|
| **Understand project mission** | `concepts/project-overview.md` |
| **Enforce module boundaries** | `concepts/architecture.md` |
| **Write production code** | `guides/coding-standards.md` |
| **Extend rule DSL safely** | `guides/rule-dsl-design.md` |
| **Keep Lisp idiomatic** | `guides/lisp-style-guide.md` |
| **Design and verify tests** | `guides/testing-guidelines.md` |
| **Manage OCICL dependencies** | `guides/dependency-management.md` |
| **Use cl-tron-mcp loop** | `guides/cl-tron-workflow.md` |

---

## By Type

**Concepts** -> project goals, architecture constraints.
**Guides** -> implementation rules, style, DSL, tests, dependencies.

---

## Related Context

- `../core/context-system/standards/frontmatter.md`
- `../core/context-system/standards/templates.md`
- `../core/context-system/standards/mvi.md`
