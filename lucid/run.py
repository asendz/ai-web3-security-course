"""CLI: point lucid at a directory of contracts and print what it finds.

    python -m lucid.run                       # scans the default target
    python -m lucid.run path/to/contracts     # scans a directory you choose

This is the whole L2 harness, end to end: load the codebase, run the agent,
print the findings. Nothing is scored or judged yet — that is Module 2. Here we
just look honestly at what a single reasoning agent catches.
"""

import sys
from pathlib import Path

from dotenv import load_dotenv

from .agent import find_bugs
from .codebase import load_codebase
from .schema import Finding

# Load KEY=VALUE pairs from a local .env file into the environment, so the
# API key you put in .env (see README setup) is picked up automatically.
load_dotenv()

# Default scan target: the SecondSwap contracts that ship with the course.
# Resolved relative to the repo root so it works from anywhere.
DEFAULT_TARGET = Path(__file__).resolve().parent.parent / "target" / "src"

# Order severities worst-first when we print.
_SEVERITY_RANK = {"critical": 0, "high": 1, "medium": 2, "low": 3}


def _print_finding(index: int, finding: Finding) -> None:
    """Pretty-print one finding as a readable block."""
    print(f"\n[{index}] {finding.severity.upper()}  —  {finding.title}")
    print(f"    location: {finding.location}")
    print(f"    what:     {finding.description}")
    print(f"    impact:   {finding.impact}")
    print("    exploit:")
    for step_no, step in enumerate(finding.exploit_steps, start=1):
        print(f"      {step_no}. {step}")


def main() -> None:
    # Arg 1 is an optional path; otherwise scan the bundled target.
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_TARGET

    print(f"Loading codebase from: {target}")
    codebase = load_codebase(str(target))
    print(f"Loaded {len(codebase):,} chars. Asking the agent...\n")

    findings = find_bugs(codebase)

    # Sort worst-first so the scariest thing is at the top.
    findings.sort(key=lambda f: _SEVERITY_RANK.get(f.severity, 99))

    if not findings:
        print("No findings returned.")
        return

    print(f"=== {len(findings)} finding(s) ===")
    for i, finding in enumerate(findings, start=1):
        _print_finding(i, finding)


if __name__ == "__main__":
    main()
