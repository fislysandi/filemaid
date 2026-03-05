# Filemaid Rule Examples

This folder contains ready-to-use rule files for common automation scenarios.

## Usage

Preview first:

```bash
filemaid preview examples/documents-rules.lisp --verbose
```

Apply with confirmation:

```bash
filemaid run examples/documents-rules.lisp
```

Apply non-interactively:

```bash
filemaid run examples/documents-rules.lisp --yes
```

## Available Examples

- `documents-rules.lisp` - Sort PDFs, markdown, and text files.
- `media-rules.lisp` - Route images/videos and tag archives.
- `cleanup-rules.lisp` - Remove temporary files and move logs.
