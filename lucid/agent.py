"""The agent: codebase in, structured findings out.

This is where the naive prompt ("find the bugs") becomes an engineered one. The
difference is not magic words — it is four disciplines baked into the prompt:

  1. ROLE + PRIORITIES — tell the model who it is and what counts as a real bug,
     ranked by impact. A model that knows it is hunting fund-loss bugs, not lint,
     spends its reasoning where it matters.
  2. REASON, THEN ANSWER — let it think freely first, but return ONLY JSON. The
     thinking improves the answer; the JSON keeps the output usable.
  3. EVIDENCE DISCIPLINE — every finding must carry a location, the flawed logic,
     the impact, and concrete steps. This is what separates a finding from a
     guess, and it makes hallucinations easy to catch.
  4. A FIXED SCHEMA — the `Finding` model. The model fills in the blanks; we
     validate what comes back.

We do NOT tell the model the answer, hint at bug classes, or run specialist
passes here. That is deliberate — this is the honest L2 baseline. The smarter
machinery arrives in later modules.
"""

from pydantic import ValidationError

from . import llm
from .schema import Finding

# --- The system prompt: who the model is and how it must behave. -------------
# Kept standing and stable. It sets the role and the two hard rules (JSON only,
# evidence always).
SYSTEM_PROMPT = """\
You are a senior smart-contract security auditor. Your job is to read Solidity \
source and find real vulnerabilities — bugs an attacker could actually exploit, \
or that would break the protocol's core guarantees.

You reason like an auditor: you build a mental model of what each contract is \
supposed to guarantee, then hunt for the cases where the code breaks that \
guarantee. You care about intent, not surface patterns.

Two rules you never break:
1. You output ONLY a single JSON object. No prose, no markdown, no code fences \
around it.
2. You never report a bug you cannot back with evidence: an exact location, the \
specific flawed logic, and concrete steps to trigger it.
"""

# --- The user prompt template: the task and the rules for THIS run. ----------
# The {codebase} placeholder is filled with the concatenated .sol blob.
# Note: the doubled braces `{{ }}` below are str.format escaping for the literal
# JSON we show the model — they render as single braces. The ONLY real
# placeholder str.format fills is `{codebase}`.
USER_PROMPT_TEMPLATE = """\
Audit the following codebase and report the vulnerabilities you find.

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
or worry about false positives: surface every issue you can back with the \
evidence discipline below, including marginal or narrow-condition cases. \
Deciding what is worth acting on is a downstream step, not this one.

# How to work
Think step by step BEFORE you answer. Silently, for each contract: what is it \
supposed to guarantee? Who is trusted? Where does value move? Then look for the \
places where the code contradicts its own intent. Do this reasoning internally. \
Do NOT include it in your output.

# Coverage
Do not stop after the first one or two issues you notice. Walk every contract \
and every state-changing function in the codebase — deposits, withdrawals, \
transfers, admin actions, and any view function that gates a money-moving path \
— and check each one against the guarantees above before you finalize your \
answer. A contract with five real bugs should produce five findings, not \
whichever one caught your attention first. This does not relax the evidence \
bar above: report every real bug you can back with evidence, and only those.

# Evidence discipline (required for every finding)
- location: the file and line (e.g. "SecondSwap_Marketplace.sol:212") or the \
exact function — precise enough that a reader lands on it immediately. Use the \
`// FILE:` markers to get the file right.
- description: name the specific flawed logic. Quote or paraphrase the offending \
line(s) so it is verifiable, not vague.
- impact: state concretely what an attacker gains or what breaks.
- exploit_steps: an ordered list of concrete actions that trigger the bug.
If you cannot fill all of these honestly, drop the finding.

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
If you find nothing you can back with evidence, return {{"findings": []}}.

# Codebase
{codebase}
"""


def find_bugs(codebase: str) -> list[Finding]:
    """Run the agent over a codebase blob and return validated findings.

    Args:
        codebase: the concatenated .sol source (see codebase.load_codebase).

    Returns:
        A list of `Finding` objects. Findings the model returns in a broken shape
        are skipped rather than crashing the run — a single malformed entry
        should not throw away the good ones.
    """
    user_prompt = USER_PROMPT_TEMPLATE.format(codebase=codebase)

    # One call. This is the entire "agent" at L2: prompt in, JSON out.
    raw = llm.complete(SYSTEM_PROMPT, user_prompt, json_mode=True)

    # Parse the reply into a dict, tolerating fences/preamble. If the reply just
    # won't parse, say so in one friendly line rather than dumping a traceback —
    # a parse failure means "no usable findings", not a crash.
    try:
        data = llm.extract_json(raw)
    except ValueError:
        print("[could not parse the model's reply as JSON — treating as no findings]")
        return []

    # We expect a JSON object like {"findings": [...]}. If the model returned
    # something else (a bare list, a string, ...), degrade gracefully to zero
    # findings instead of crashing on .get(...).
    if not isinstance(data, dict):
        print("[model reply was not a JSON object — treating as no findings]")
        return []

    # The model returns {"findings": [...]}. Validate each entry against our
    # schema; drop (but announce) any that don't fit.
    findings: list[Finding] = []
    for item in data.get("findings", []):
        try:
            findings.append(Finding(**item))
        except (ValidationError, TypeError) as err:
            print(f"[skipped a malformed finding] {err}")
    return findings
