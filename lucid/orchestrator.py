"""Module 3: fan out the specialists — plus the general hunter — in parallel,
each one looped.

This file is pure plumbing, not reasoning. The reasoning lives in each
specialist's own prompt (see `lucid/specialists.py`) — a focused lens on one
vulnerability class, run over the same codebase and context every other lane
sees. What this file adds is the fan-out itself: running all five specialists
AND Module 2's context-aware general hunter concurrently, in the same batch,
rather than one after another. The general hunter rides along as a sixth,
unfocused lane — broad instead of specialized — so its findings feed into the
judge alongside the specialists' instead of being treated as a separate,
earlier stage. That is also why this fan-out buys the specialists their
parallelism for free: five extra focused lenses, same wall-clock time as
running the general hunter alone, because all six calls are in flight
together, not five calls stacked in sequence after the general hunter
finishes.

Every lane is looped, not single-shot: each specialist runs through
`specialists.run_specialist_loop` (Module 2's self-excluding loop, applied
per specialist) and the general hunter runs through `agent.find_bugs_loop`
(the same loop Module 2 shipped) instead of a single context-aware pass. The
six lanes still run concurrently with each other - only each lane's own
`rounds` passes are sequential within that lane, exactly mirroring how
Module 2's loop worked before any specialists existed.

The LLM calls in `lucid/llm.py` are synchronous (no async/await, by design —
see llm.py's own docstring), but they are I/O-bound: the process spends its
time waiting on a network response, not on CPU. A ThreadPoolExecutor is the
right tool for that — real parallelism for I/O waits, no asyncio required.
"""

from concurrent.futures import ThreadPoolExecutor, as_completed

from .agent import find_bugs_loop
from .schema import Finding
from .specialists import SPECIALISTS, run_specialist_loop

# The general hunter's lane key, alongside the specialist keys from
# SPECIALISTS. Not a specialist itself — Module 2's existing broad,
# context-aware, looped pass — but it goes in the same pool/dict as one more
# named lane, so the judge reconciles across all six rather than treating it
# separately.
GENERAL_HUNTER_KEY = "general_hunter"

# Default round count per lane - every lane (specialist or general) loops this
# many times unless told otherwise. 10, not Module 2's 5: this is the setup
# Module 3's published numbers were measured with (target/runs/m3-run-*.json,
# `rounds_per_lane: 10`), so running with no arguments reproduces them.
_DEFAULT_LANE_ROUNDS = 10


def run_specialists_parallel(
    codebase: str, context: str, rounds: int = _DEFAULT_LANE_ROUNDS
) -> dict[str, list[Finding]]:
    """Run all 5 specialists AND the general hunter concurrently, one batch,
    each one looped for `rounds` rounds internally.

    Args:
        codebase: the concatenated .sol source (see codebase.load_codebase).
        context: the output of context.build_context(codebase) — every lane,
            specialist or general, reasons over the same protocol context.
        rounds: how many self-excluding rounds each lane runs internally
            (same meaning as find_bugs_loop's `rounds` - default 10, the
            setup Module 3 was measured with).

    Returns:
        A dict mapping each lane's key to its list of Finding objects: the 5
        specialist keys from SPECIALISTS, plus GENERAL_HUNTER_KEY. Deliberately
        NOT flattened into one list — the judge needs to know which lens found
        what to reconcile them intelligently. A lane that fails contributes an
        empty list under its key rather than dropping out of the dict
        entirely, so the judge always sees all six keys.
    """
    findings_by_specialist: dict[str, list[Finding]] = {}

    # One worker per lane — five specialists plus the general hunter, six
    # long-lived threads (each now runs `rounds` sequential calls, not one),
    # not a pool sized for reuse. Submitting the general hunter into this
    # SAME executor (rather than calling it before or after) is what keeps
    # the specialists' extra coverage from costing extra wall-clock time -
    # total fan-out time is bounded by the slowest lane's `rounds` calls, not
    # the sum of all six lanes' calls.
    total_lanes = len(SPECIALISTS) + 1
    with ThreadPoolExecutor(max_workers=total_lanes) as executor:
        future_to_key = {
            executor.submit(run_specialist_loop, codebase, context, specialist["key"], rounds): specialist["key"]
            for specialist in SPECIALISTS
        }
        future_to_key[executor.submit(find_bugs_loop, codebase, context, rounds)] = GENERAL_HUNTER_KEY

        print(f"  [{GENERAL_HUNTER_KEY}] running {rounds} rounds (Module 2's "
              "find_bugs_loop - reports once, when it finishes)", flush=True)

        # as_completed, not submission order, so each lane announces itself
        # the moment it's done instead of waiting behind a slower one.
        for future in as_completed(future_to_key):
            key = future_to_key[future]
            try:
                findings_by_specialist[key] = future.result()
                print(f"  [{key}] done - {len(findings_by_specialist[key])} "
                      f"finding(s)", flush=True)
            except Exception as err:
                # A single lane crashing (bad JSON, API error, whatever)
                # should not take down the other five. Say so and move on with
                # an empty list for that lane — same "degrade, don't crash"
                # posture as the parse failures in agent.py.
                print(f"[lane '{key}' failed — continuing without it] {err}")
                findings_by_specialist[key] = []

    return findings_by_specialist
