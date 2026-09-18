"""CLI: point lucid at a directory of contracts and print what it finds.

    python -m lucid.run                      # scans the default target
    python -m lucid.run path/to/contracts    # scans a directory you choose
    python -m lucid.run --context            # Module 2: context + single hunt
    python -m lucid.run --loop               # Module 2: context + 5-round loop
    python -m lucid.run --loop 3             # Module 2: context + N-round loop

With no flags this is still the whole L2 harness, end to end: load the
codebase, run the plain agent, print the findings — unchanged from Module 1.
`--context` and `--loop` opt into Module 2's additions
(`lucid/context.py`'s `build_context`, plus `lucid/agent.py`'s
`find_bugs_with_context` and `find_bugs_loop`): `--context` builds a protocol-
context document then runs one context-aware hunt; `--loop` does the same but
runs the exclusion loop for several rounds (5 by default, or pass a number).
Neither flag adds a judge — Module 2 shipped context and a loop, not a judge,
so nothing here is scored or judged yet; that is still later.
"""

import sys
from pathlib import Path

from dotenv import load_dotenv

from .agent import find_bugs, find_bugs_loop, find_bugs_with_context
from .codebase import load_codebase
from .context import build_context
from .schema import Finding

# Load KEY=VALUE pairs from a local .env file into the environment, so the
# API key you put in .env (see README setup) is picked up automatically.
load_dotenv()

# Default scan target: the SecondSwap contracts that ship with the course.
# Resolved relative to the repo root so it works from anywhere.
DEFAULT_TARGET = Path(__file__).resolve().parent.parent / "target" / "src"

# Order severities worst-first when we print.
_SEVERITY_RANK = {"critical": 0, "high": 1, "medium": 2, "low": 3}

# Default round count for --loop when no number follows it. Matches the
# 5-round sequences Module 2 measured in lucid/agent.py's find_bugs_loop.
_DEFAULT_LOOP_ROUNDS = 5


def _parse_args(argv: list[str]) -> tuple[Path, bool, int | None]:
    """Parse the CLI's tiny surface: an optional target path, plus Module 2's
    opt-in flags.

    Kept as plain argv scanning rather than argparse — this mirrors the rest
    of the harness's philosophy of a few readable lines over a dependency.

    Returns:
        (target, use_context, loop_rounds). loop_rounds is None unless --loop
        was passed, in which case it is the round count (default
        _DEFAULT_LOOP_ROUNDS). --loop implies context, same as
        find_bugs_loop's own signature requires.
    """
    target = DEFAULT_TARGET
    use_context = False
    loop_rounds: int | None = None

    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--context":
            use_context = True
        elif arg == "--loop":
            loop_rounds = _DEFAULT_LOOP_ROUNDS
            # An optional following integer sets the round count: `--loop 3`.
            if i + 1 < len(argv) and argv[i + 1].isdigit():
                i += 1
                loop_rounds = int(argv[i])
        else:
            target = Path(arg)
        i += 1

    return target, use_context, loop_rounds


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
    target, use_context, loop_rounds = _parse_args(sys.argv[1:])

    print(f"Loading codebase from: {target}")
    codebase = load_codebase(str(target))

    # --loop implies a context pass too (find_bugs_loop always reasons over
    # invariants, same as find_bugs_with_context) - so check it first. The
    # plain (no-flag) branch below prints the single combined line Module 1
    # shipped, byte-for-byte - the two-step "Loaded... / Building context..."
    # staging only applies to Module 2's new paths, which have an extra step
    # to narrate.
    if loop_rounds is not None:
        print(f"Loaded {len(codebase):,} chars.")
        print("Building protocol context (Module 2's build_context)...\n")
        context = build_context(codebase)
        print(f"Running find_bugs_loop for {loop_rounds} round(s)...\n")
        findings = find_bugs_loop(codebase, context, rounds=loop_rounds)
    elif use_context:
        print(f"Loaded {len(codebase):,} chars.")
        print("Building protocol context (Module 2's build_context)...\n")
        context = build_context(codebase)
        print("Asking the context-aware agent...\n")
        findings = find_bugs_with_context(codebase, context)
    else:
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
