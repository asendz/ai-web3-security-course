"""Module 3: reconcile the pooled findings from six lanes into one final list.

Five specialists each read the same codebase through a different lens (see
`lucid/specialists.py`), and a sixth lane — Module 2's existing context-aware
general hunter, looped via `agent.find_bugs_loop`, fanned out in the same batch
by `orchestrator.run_specialists_parallel` — reads it broadly, unfocused. All
six can legitimately disagree, overlap, or flag the same root cause in
different words. Deduplicating that pool with string matching or a similarity
threshold would throw away exactly the judgment this course is teaching:
whether two findings are "the same bug" is a reasoning question — does
contract X's broken guarantee under one lane's framing match the broken
guarantee another lane independently landed on? — not a text-matching one.
So the judge is a model call, not a hash set.

The judge also gets the codebase itself, not just the findings about it.
Measured evidence for why: the known "unprotected upgradeable initializer"
false-positive pattern (see specialists.py's trust_boundary exclusion, added
for that one lane) still reached the final judged output at CRITICAL
severity, in every real run measured before this fix — a specialist's
confident, well-formed-looking claim that the judge had no way to check,
because it never saw the code the claim was supposedly about. A finding can
be internally consistent (real location, real-sounding mechanism, concrete
exploit steps) and still be false about this specific codebase. Only reading
the cited location catches that. So the judge cross-checks each finding
against the actual source before it keeps it, not just against the other
findings in the pool.

This mirrors the call/parse/validate pattern in agent.py's
find_bugs_with_context: one prompt in, one JSON object out, validated into
Finding objects. What's different is the input shape - a pool of findings
already tagged with which specialist reported them, plus the codebase they're
about - and the job: merge and verify, not discover from scratch.
"""

from pydantic import ValidationError

from . import llm
from .orchestrator import GENERAL_HUNTER_KEY
from .schema import Finding
from .specialists import SPECIALISTS

# --- The system prompt: who the judge is and how it must behave. ------------
JUDGE_SYSTEM_PROMPT = """\
You are the senior reviewer on a smart-contract security audit. Six auditors \
each independently reviewed the same codebase: five specialists, each \
looking through a different focused lens (state machine correctness, trust \
boundaries, arithmetic, staleness, edge cases), plus one generalist who read \
the whole codebase broadly without a specific lens. Your job is to take \
their pooled findings and produce the one final list that would go in the \
report - and unlike them, you have the codebase in front of you too. Use it: \
an auditor can write a confident, well-formed finding that is simply wrong \
about what this specific code does. Reading the cited location yourself is \
the only way to catch that.

Three rules you never break:
1. You output ONLY a single JSON object. No prose, no markdown, no code fences \
around it.
2. You never keep a finding you cannot back with evidence: an exact location, \
the specific flawed logic, and concrete steps to trigger it. A finding that \
fails this bar gets dropped, even if a specialist reported it.
3. You never keep a finding whose central claim the actual code directly \
contradicts once you read the location it cites - but ordinary uncertainty \
the code neither confirms nor denies is not the same as a contradiction, and \
gets the benefit of the doubt.
"""

# --- The user prompt template: the pooled findings, the codebase, and the
# reconciliation rules for this run. The {pooled_findings} and {codebase}
# placeholders are filled in judge_findings below. Note: the doubled braces
# `{{ }}` are str.format escaping for the literal JSON shown to the model.
JUDGE_USER_PROMPT_TEMPLATE = """\
Below are the findings reported by six auditors — five specialists plus one \
generalist — each of whom reviewed the full codebase independently. \
Reconcile them into the final findings list for this audit.

# Your job
1. MERGE duplicates: if two or more auditors describe the SAME underlying \
bug — same root cause, even if the wording, title, or emphasis differs — \
combine them into a single finding. Write the merged finding's description \
and evidence from whichever auditor(s) stated it most precisely; do not \
just concatenate their text.
2. KEEP distinct findings separate: two findings that touch the same \
function or contract but stem from different root causes, or that break \
different guarantees, are NOT duplicates — keep both, even if they sound \
similar at a glance.
3. ASSIGN final severity using the ladder below. When auditors disagree on \
severity for what you've merged into one finding, decide based on the actual \
impact described, not by averaging or defaulting to the higher label.
4. KEEP by default. A finding stays in unless you have a positive reason to \
remove it under rule 5 or 6 below - a real evidence gap, or a direct \
contradiction with the code. Not being able to independently re-derive a \
finding from scratch is not a reason to drop it; checking it against the \
code is your job, re-auditing from zero is not.
5. DROP anything that doesn't meet the evidence bar: no exact location, no \
concrete flawed logic, or no reachable exploit steps. Auditors sometimes \
over-report; your list should not.
6. VERIFY against the codebase below, and drop on CONTRADICTION, not on \
absence of proof. For every finding, read the code at its cited location. If \
the code directly contradicts the finding's central claim - the pattern it \
describes isn't there, or a precondition it assumes false is actually true - \
drop it, no matter how confident or well-formatted the report reads. But if a \
finding's exploitability depends on something these files neither confirm \
nor contradict (deployment specifics, off-chain behavior), that is ordinary \
uncertainty, not disqualifying - keep it, the same way a human auditor would \
flag it as worth checking rather than dismiss it unread.
7. ONE NAMED EXCEPTION to rule 6: do not keep a finding that claims a generic \
"unprotected" or "uninitialized upgradeable initializer permits takeover" - \
importing `Initializable` and exposing a public `initialize()` with no \
constructor guard - unless the finding itself cites an actual proxy contract \
or deployment script IN THIS CODEBASE that puts the contract behind one. \
This specific pattern is a known reflex: a model trained on real \
upgradeable-proxy writeups reaches for it whenever it sees `Initializable`, \
whether or not this codebase actually uses a proxy. Auditors in this pool \
have made exactly this mistake before. Hold this one named pattern to a \
higher bar than rule 6's general default - everything else in this pool \
still gets the benefit of the doubt rule 4 describes.

# What counts as a real bug (prioritise by impact, highest first)
- CRITICAL: direct theft, loss, or permanent locking of user or protocol funds; \
minting or draining value; bypassing core access control on money-moving paths.
- HIGH: fund loss that needs a specific (but reachable) condition; breaking a \
core accounting or vesting invariant; a griefing attack that denies others their \
funds.
- MEDIUM: value leakage or mis-accounting under narrower conditions; incorrect \
math (rounding, over/underflow logic, inverted comparisons) that harms a party; \
recoverable denial of service.

Ignore style, gas, pure best-practice nits, and Low-severity edge cases — stay \
at Medium and above. Within that floor, do not filter for perceived importance \
or worry about false positives: keep every issue you can back with the \
evidence discipline below, including marginal or narrow-condition cases. \
Deciding what is worth acting on is a downstream step, not this one.

# How to work
Think step by step BEFORE you answer. Silently: read every auditor's pool. \
For each finding, check whether another auditor independently reported the \
same root cause elsewhere in the pool — if so, that is a merge candidate, not \
two findings. Then, for every finding or merged group still standing, go to \
its cited location in the codebase below and check the claim against the \
actual code - looking for a direct contradiction, not for independent proof. \
Watch specifically for rule 7's named pattern while you do this. Everything \
else that clears the evidence bar and isn't contradicted stays in. Do this \
reasoning \
internally. Do NOT include it in your output.

# Evidence discipline (required for every finding you keep)
- location: the file and line (e.g. "SecondSwap_Marketplace.sol:212") or the \
exact function — precise enough that a reader lands on it immediately.
- description: name the specific flawed logic. Quote or paraphrase the offending \
line(s) so it is verifiable, not vague.
- impact: state concretely what an attacker gains or what breaks.
- exploit_steps: an ordered list of concrete actions that trigger the bug.
If a finding in the pool cannot be backed this well even after merging \
auditors' reports, drop it rather than keep it half-supported.

# Output format
Return ONLY this JSON object, nothing else:
{{
  "findings": [
    {{
      "title": "short specific name",
      "severity": "critical | high | medium",
      "location": "file:line or function",
      "description": "the flawed logic, verifiable",
      "impact": "what an attacker gains / what breaks",
      "exploit_steps": ["step 1", "step 2", "..."]
    }}
  ]
}}
If nothing in the pool survives merging, verification, and the evidence bar, \
return {{"findings": []}}.

# Pooled findings, by auditor
{pooled_findings}

# Codebase
{codebase}
"""

# Look up a lane's display name by key, for formatting the pool below. Covers
# the 5 specialist keys from SPECIALISTS plus the general hunter's key, which
# isn't a specialist and so isn't in that list.
_LANE_NAMES = {s["key"]: s["name"] for s in SPECIALISTS}
_LANE_NAMES[GENERAL_HUNTER_KEY] = "General Hunter (broad, unfocused pass)"


def _format_pool(findings_by_specialist: dict[str, list[Finding]]) -> str:
    """Render the pooled findings as readable text, one block per lane.

    Each lane's findings are listed in full — title, severity, location,
    description, impact, exploit steps — since the judge needs enough detail
    to tell whether two findings share a root cause, not just their titles.
    """
    blocks = []
    for key, findings in findings_by_specialist.items():
        name = _LANE_NAMES.get(key, key)
        header = f"## {name} ({key})"
        if not findings:
            blocks.append(f"{header}\n(no findings from this lane)")
            continue

        lines = [header]
        for i, f in enumerate(findings, start=1):
            steps = "; ".join(f.exploit_steps)
            lines.append(
                f"{i}. [{f.severity.upper()}] {f.title}\n"
                f"   location: {f.location}\n"
                f"   description: {f.description}\n"
                f"   impact: {f.impact}\n"
                f"   exploit_steps: {steps}"
            )
        blocks.append("\n".join(lines))

    return "\n\n".join(blocks)


def judge_findings(
    findings_by_specialist: dict[str, list[Finding]], codebase: str
) -> list[Finding]:
    """Reconcile the pooled, lane-tagged findings into one final list.

    Args:
        findings_by_specialist: the output of
            orchestrator.run_specialists_parallel — findings keyed by which
            lane reported them (the 5 specialist keys plus
            orchestrator.GENERAL_HUNTER_KEY).
        codebase: the same concatenated .sol source every lane already read
            (see codebase.load_codebase). The judge cross-checks each
            finding's claim against this before keeping it - see the module
            docstring for why that matters.

    Returns:
        A list of `Finding` objects: the pool merged, verified against the
        code, severity-confirmed, and evidence-filtered. If every lane found
        nothing, returns [] without calling the model — there is nothing to
        judge.
    """
    if not any(findings_by_specialist.values()):
        return []

    pooled_findings = _format_pool(findings_by_specialist)
    user_prompt = JUDGE_USER_PROMPT_TEMPLATE.format(
        pooled_findings=pooled_findings, codebase=codebase
    )

    raw = llm.complete(JUDGE_SYSTEM_PROMPT, user_prompt, json_mode=True)

    try:
        data = llm.extract_json(raw)
    except ValueError:
        print("[could not parse the judge's reply as JSON — treating as no findings]")
        return []

    if not isinstance(data, dict):
        print("[judge reply was not a JSON object — treating as no findings]")
        return []

    findings: list[Finding] = []
    for item in data.get("findings", []):
        try:
            findings.append(Finding(**item))
        except (ValidationError, TypeError) as err:
            print(f"[skipped a malformed finding] {err}")
    return findings
