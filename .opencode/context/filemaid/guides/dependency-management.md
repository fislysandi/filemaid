<!-- Context: filemaid/guides | Priority: critical | Version: 1.0 | Updated: 2026-03-05 -->
# Guide: Dependency Management

**Purpose**: Enforce reproducible, minimal dependency strategy for Filemaid using OCICL and SBCL.
**Last Updated**: 2026-03-05

## Prerequisites
- OCICL installed in development environment.
- SBCL toolchain available for local builds and tests.

**Estimated time**: 10 min

## Policy
- All external dependencies are managed through OCICL.
- SBCL is the primary supported runtime for clean builds.
- Add dependencies only when core Lisp alternatives are insufficient.
- Keep lockable/reproducible dependency state under version control.

## Steps

### 1. Evaluate necessity
- Confirm dependency solves a real gap and is actively maintained.
- Reject dependencies used for convenience-only abstractions.

### 2. Add via OCICL
- Register and pin using project OCICL workflow.
- Record rationale in commit or docs when adding new packages.

### 3. Validate reproducibility
- Run clean SBCL build from fresh dependency state.
- Confirm tests pass with resolved OCICL set.

### 4. Guard Python bridge scope
- Keep `py4cl-cffi` optional and narrow.
- Do not move core decision logic into Python modules.

## Verification
- Fresh setup builds without manual dependency patching.
- SBCL run and tests succeed with OCICL-managed deps only.
- Dependency graph remains minimal and documented.

## 📂 Codebase References

**Dependency Entrypoints**:
- `ocicl.lisp` - dependency bootstrap and resolution flow.
- `filemaid.asd` - system dependency declarations.

**Optional Python Integration**:
- `src/python-bridge.lisp` - py4cl-cffi boundary.
- `python/metadata.py` - auxiliary metadata helpers only.

**Validation**:
- `tests/core-tests.lisp` - runtime compatibility checks.

## Related
- concepts/project-overview.md
- guides/testing-guidelines.md
