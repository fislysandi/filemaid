"""Optional Python helpers for Filemaid integration points.

This file intentionally contains helper utilities only.
Core application logic remains in Common Lisp.
"""

from pathlib import Path


def file_suffix(path: str) -> str:
    return Path(path).suffix.lower().lstrip(".")


def pdf_contains_text(path: str, needle: str) -> bool:
    """Placeholder implementation for optional PDF search integration."""
    _ = (path, needle)
    return False
