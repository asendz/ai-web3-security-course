"""Load a Solidity codebase into a single text blob.

The naive move most people skip: just give the model everything at once. A
frontier model has a big context window, so for a small protocol we can drop the
whole thing into one prompt and let the model reason across files.

`load_codebase` walks a directory, reads every .sol file, and concatenates them
with a `// FILE:` marker before each one so the model (and you) can tell where
each file starts. Within each file we also prefix every source line with its
line number, so when the model cites `file:line` that number is real and a
reader can verify it — evidence discipline starts at the input.
"""

from pathlib import Path

# A safety rail. If the concatenated code is bigger than this, we stop instead
# of silently sending a giant (and expensive, maybe over-limit) prompt. For a
# small protocol like our target this is comfortably enough; raise it when you
# point lucid at something larger.
MAX_CHARS = 400_000


def load_codebase(path: str) -> str:
    """Concatenate every .sol file under `path` into one annotated blob.

    Each file is preceded by a `// FILE: <relative/path>` marker so the model
    knows which file it is reading, and every source line is prefixed with its
    original line number so the model can cite `file:line` locations that are
    real and verifiable rather than guessed.

    Args:
        path: directory to scan (recursively). Everything under it is included —
              contracts and interfaces alike — because the model needs the
              interfaces to understand the contracts.

    Returns:
        One big string: every .sol file, in sorted path order, each with a
        header marker.

    Raises:
        FileNotFoundError: if `path` is not a directory.
        ValueError:        if the combined size exceeds MAX_CHARS.
    """
    root = Path(path)
    if not root.is_dir():
        raise FileNotFoundError(f"Not a directory: {path}")

    # Sort so the output is stable run-to-run — a deterministic harness starts
    # with deterministic inputs.
    sol_files = sorted(root.rglob("*.sol"))
    if not sol_files:
        raise ValueError(f"No .sol files found under {path}")

    parts: list[str] = []
    total = 0
    for file in sol_files:
        rel = file.relative_to(root)
        source = file.read_text(encoding="utf-8", errors="replace")

        # Prefix each line with its 1-based line number so the model can cite
        # real `file:line` locations. A raw concatenation carries no line data,
        # so any line the model returned would otherwise be fabricated.
        numbered = "\n".join(
            f"{i}: {line}" for i, line in enumerate(source.splitlines(), start=1)
        )
        block = f"// FILE: {rel}\n{numbered}\n"

        total += len(block)
        if total > MAX_CHARS:
            raise ValueError(
                f"Codebase exceeds {MAX_CHARS:,} chars after adding {rel}. "
                "Raise MAX_CHARS or scan fewer files. (Later modules split big "
                "codebases up instead of sending them whole.)"
            )
        parts.append(block)

    return "\n".join(parts)
