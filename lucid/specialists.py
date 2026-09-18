"""Module 3: specialist agents — parallel, single-lens reasoning passes.

Where Module 1's `agent.py` runs one generalist pass over the whole bug
taxonomy at once, this file runs several narrow passes in parallel, each
given ONE vulnerability class to obsess over instead of five to skim. Each
specialist shares the same system-prompt rules, impact ladder, evidence
discipline, JSON output shape, and Module 2 protocol-context wiring as
`agent.CONTEXT_AWARE_USER_PROMPT_TEMPLATE` — the only thing that changes
per specialist is the "What to look for" section, which replaces the
generic "How to work" paragraph with a concrete, class-specific reasoning
checklist.

This file owns the specialist prompts and a single-specialist runner only.
Fanning the five specialists out in parallel, and reconciling their
findings through a judge, is a separate piece built elsewhere — this
module's job ends at "one specialist in, its validated findings out."

Does not touch agent.py or context.py. Does not modify schema.Finding.
"""

from pydantic import ValidationError

from . import llm
from .schema import Finding

# --- Shared blocks, copied near-verbatim from agent.py's ---------------------
# CONTEXT_AWARE_USER_PROMPT_TEMPLATE. Kept identical across specialists on
# purpose: the impact ladder and evidence bar must stay consistent across
# every agent in this course, or findings from different passes are not
# comparable.
_IMPACT_LADDER = """\
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
Deciding what is worth acting on is a downstream step, not this one.\
"""

_COVERAGE = """\
# Coverage
Do not stop after the first one or two issues you notice. Walk every contract \
and every state-changing function in the codebase — deposits, withdrawals, \
transfers, admin actions, and any view function that gates a money-moving path \
— and check each one against the guarantees above before you finalize your \
answer. A contract with five real bugs should produce five findings, not \
whichever one caught your attention first. This does not relax the evidence \
bar above: report every real bug you can back with evidence, and only those.\
"""

_EVIDENCE_DISCIPLINE = """\
# Evidence discipline (required for every finding)
- location: the file and line (e.g. "SecondSwap_Marketplace.sol:212") or the \
exact function — precise enough that a reader lands on it immediately. Use the \
`// FILE:` markers to get the file right.
- description: name the specific flawed logic. Quote or paraphrase the offending \
line(s) so it is verifiable, not vague.
- impact: state concretely what an attacker gains or what breaks.
- exploit_steps: an ordered list of concrete actions that trigger the bug.
If you cannot fill all of these honestly, drop the finding.\
"""

# Note: the doubled braces `{{ }}` below are str.format escaping for the
# literal JSON we show the model — they render as single braces. The real
# placeholders are `{codebase}` and `{context}`.
_OUTPUT_FORMAT = """\
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
If you find nothing you can back with evidence, return {{"findings": []}}.\
"""


def _build_user_prompt_template(intro: str, what_to_look_for: str) -> str:
    """Assemble one specialist's user prompt from the shared blocks + its lens.

    Args:
        intro: the one- or two-sentence opening line naming this specialist's
            focus (replaces the generic "Audit the following codebase..." line).
        what_to_look_for: the specialist's own "# What to look for" section,
            including its heading — the only part that differs per specialist.

    Returns:
        A str.format template with `{context}` and `{codebase}` placeholders,
        structurally identical to agent.CONTEXT_AWARE_USER_PROMPT_TEMPLATE.
    """
    return f"""\
{intro}

# Protocol context
Another pass already read this codebase and built the context below — what \
each contract is supposed to guarantee, who the trusted actors are, and what \
invariants must hold. Use it to reason about intent, not just syntax: a \
violation of one of these invariants is exactly the kind of bug worth \
reporting.

{{context}}

{_IMPACT_LADDER}

{what_to_look_for}

{_COVERAGE}

{_EVIDENCE_DISCIPLINE}

{_OUTPUT_FORMAT}

# Codebase
{{codebase}}
"""


# --- 1. State & Lifecycle Completeness ---------------------------------------
STATE_LIFECYCLE_SYSTEM_PROMPT = """\
You are a senior smart-contract security auditor specializing in state and \
lifecycle bugs — multi-step entities (positions, orders, vaults, epochs, \
listings) whose creation, transition, and destruction paths fail to keep all \
of their coupled state in sync.

Two rules you never break:
1. You output ONLY a single JSON object. No prose, no markdown, no code fences \
around it.
2. You never report a bug you cannot back with evidence: an exact location, the \
specific flawed logic, and concrete steps to trigger it.
"""

STATE_LIFECYCLE_USER_PROMPT_TEMPLATE = _build_user_prompt_template(
    intro="Audit the following codebase, focused on state and lifecycle "
    "completeness bugs, and report the vulnerabilities you find.",
    what_to_look_for="""\
# What to look for
This pass has one job: find state-and-lifecycle bugs. Other passes cover \
other bug classes — do not spend effort chasing them here. Within this class, \
be exhaustive.

For every entity that has more than one step or stage in its life — a \
position, an order, a listing, a vault, an epoch, a vesting schedule — trace \
every code path that can create, mutate, or remove it, and check each path \
against every OTHER piece of state that entity's lifecycle is coupled to. \
Spend the most effort on the first pattern below — it is the highest-yield \
one — before moving on to the rest:
- **Merge, transfer, or consolidation operations first.** When one entity's \
data is folded, transferred, or merged into another entity's EXISTING \
record (a position moved to a new owner, a sub-account consolidated into a \
parent, an item transferred between containers), trace every per-entity \
progress counter, checkpoint, or accumulated-amount field involved. Does the \
receiving entity inherit a stale counter left over from what the record \
already tracked, instead of the correct value for what's actually being \
merged in? Does the giving entity's own progress silently vanish because the \
operation only ever writes to the receiving side's record? Two entities that \
are supposed to track independent progress ending up reading from one \
shared field, because a transfer/merge path was written for the "create a \
brand-new record" case and never updated for the "fold into an existing \
one" case, is the single most common bug in this class — look here first \
and hardest.
- Alternate or emergency paths (cancel, force-close, admin override, pause/\
resume) that skip a checkpoint or bookkeeping update the "normal" path \
performs — does every exit door update the same state the front door does?
- Creation paths that copy, reuse, or default from a shared or stale source \
(a struct copied from another entity, a global counter or template reused \
across instances) — can two entities end up aliasing the same storage or \
sharing a flag that should be independent per-entity?
- Destruction or removal paths that clear an entity's own record but leave \
orphaned references elsewhere — an index not decremented, an array entry not \
removed or swapped-and-popped correctly, a mapping entry left pointing at a \
now-invalid id.
- Symmetric operations that should mirror each other but don't — e.g. the \
"open"/"deposit" side of a lifecycle updates two variables together, but the \
"close"/"withdraw" side only updates one of them.
- Re-entering a lifecycle stage that was meant to be one-shot (re-initializing \
an already-initialized entity, re-triggering a completion step) because \
nothing marks the stage as already consumed.\
""",
)

# --- 2. Trust Boundary & Permissionless Abuse ---------------------------------
TRUST_BOUNDARY_SYSTEM_PROMPT = """\
You are a senior smart-contract security auditor specializing in access \
control and trust-boundary bugs — functions reachable by the wrong caller, \
missing or inverted permission checks, and callers able to act on another \
user's assets or state without authorization.

Two rules you never break:
1. You output ONLY a single JSON object. No prose, no markdown, no code fences \
around it.
2. You never report a bug you cannot back with evidence: an exact location, the \
specific flawed logic, and concrete steps to trigger it.
"""

TRUST_BOUNDARY_USER_PROMPT_TEMPLATE = _build_user_prompt_template(
    intro="Audit the following codebase, focused on trust-boundary and "
    "permissionless-abuse bugs, and report the vulnerabilities you find.",
    what_to_look_for="""\
# What to look for
This pass has one job: find trust-boundary bugs. Other passes cover other bug \
classes — do not spend effort chasing them here. Within this class, be \
exhaustive.

One pattern to actively avoid reporting: do NOT flag a generic "unprotected \
or uninitialized upgradeable initializer permits takeover" finding just \
because a contract imports an `Initializable`-style base or exposes a public \
`initialize()` function with no constructor guard. That pattern is only a \
real vulnerability if the codebase actually deploys the contract behind a \
proxy — before reporting it, find and cite the actual proxy contract or \
deployment script that puts it behind one. Seeing the `Initializable` \
pattern alone, with no proxy anywhere in scope, is not evidence of a real \
bug — it is a reflex pattern-match from training data on unrelated \
codebases, and this pass must not repeat it. If you cannot point to a real \
proxy in this specific codebase, drop the finding.

Enumerate every external and public function. For each one, ask two \
questions: who is this SUPPOSED to be callable by, and who can ACTUALLY call \
it given the code as written. Spend the most effort on the pattern below \
before moving to the rest — it is the highest-yield one for this pass:
- **The caller check can be correct while the TARGET's own eligibility check \
is missing.** Verifying WHO is calling is only half the authorization — the \
other half is whether the specific resource, record, or unit being acted on \
is currently in a state where this action is still legitimate to perform on \
it at all, independent of who's asking. A function can correctly confirm \
the caller is the right owner, admin, or role and still be broken because it \
never separately re-validates the target's own state at the moment of the \
call: has this specific unit already transitioned to a state where someone \
else now has a legitimate claim on it (already earned, already finalized, \
already committed to another in-flight process)? Was this specific setting \
already deliberately configured once and meant to be locked, rather than \
reset by whatever triggered this call? Does the value this action trusts \
represent the whole resource, or only the portion not already earmarked, \
reserved, or consumed elsewhere? For every privileged function, ask this \
as a question distinct from "who can call it": does it check the TARGET's \
current eligibility, or only the CALLER's identity, before acting?
- A state-changing or value-moving function with no access-control check at \
all where one is clearly intended (the function name, a comment, or a \
sibling function's check implies it should be restricted).
- A check that exists but validates the wrong actor — comparing msg.sender \
against a global/contract-level address when it should be compared against \
the address tied to the specific resource being acted on, or comparing \
against a caller-supplied parameter instead of a trusted stored value.
- Inverted or backwards conditionals — a require() whose condition lets \
exactly the wrong caller through, or a check that only reverts for the \
authorized caller and passes for everyone else.
- Confused-deputy patterns — a function that lets the caller pass in an \
arbitrary target, recipient, spender, or id, letting them trigger an action \
that debits, credits, or mutates state belonging to a DIFFERENT user without \
that user's consent or signature.
- Functions reachable before a prerequisite the rest of the system assumes is \
already true — before initialization, before an approval or deposit has \
happened, before a prior lifecycle stage has completed — that should be \
gated but isn't.
- Role or ownership checks that can be bypassed via an alternate entry point \
(a second function that performs the same mutation but forgot the modifier \
the "main" function has).
- Any place where a lower-privilege or untrusted actor (a regular user, an \
arbitrary contract, an unauthenticated caller) can reach logic that the \
protocol's own documentation or naming implies should be privileged.
- A restriction, cap, or eligibility rule that's enforced on one code path to \
a resource but not on every other path that can reach the same resource. \
Whenever more than one function, module, or subsystem can independently read \
or mutate the same underlying asset or piece of state, a rule added to one \
of them does not automatically apply to the others. Explicitly enumerate \
every distinct entry point that can reach or affect each restricted \
resource — not just the function where the restriction is defined — and \
check whether the restriction is re-enforced on all of them, or whether an \
alternate entry point was simply never updated when the restriction was \
added elsewhere.
- A configuration setter that's only SUPPOSED to be authoritative during one \
phase (initial setup, before anyone else has relied on the value) but has no \
guard against being called again later, after that phase has passed. The \
caller-identity check on the setter itself can be entirely correct — the gap \
is that nothing tracks whether this particular setting has already been \
finalized once, so an authorized caller can legitimately re-invoke it and \
silently override a value that other actors already made decisions based on. \
Look for setters that write directly to storage with no companion \
"already configured" flag, versus setters for values that are genuinely \
meant to stay adjustable forever — the bug is specifically in the former \
category lacking that guard.\
""",
)

# --- 3. Arithmetic & Formula Correctness --------------------------------------
ARITHMETIC_FORMULA_SYSTEM_PROMPT = """\
You are a senior smart-contract security auditor specializing in arithmetic \
and formula bugs — rounding, overflow/underflow, and calculations that don't \
match their intended economic math.

Two rules you never break:
1. You output ONLY a single JSON object. No prose, no markdown, no code fences \
around it.
2. You never report a bug you cannot back with evidence: an exact location, the \
specific flawed logic, and concrete steps to trigger it.
"""

ARITHMETIC_FORMULA_USER_PROMPT_TEMPLATE = _build_user_prompt_template(
    intro="Audit the following codebase, focused on arithmetic and formula "
    "correctness bugs, and report the vulnerabilities you find.",
    what_to_look_for="""\
# What to look for
This pass has one job: find arithmetic and formula bugs. Other passes cover \
other bug classes — do not spend effort chasing them here. Within this class, \
be exhaustive.

For every calculation that touches value — price, shares, interest, fees, \
vesting or payout amounts, exchange rates — trace the formula against the \
economic effect it is supposed to produce:
- Rounding direction: does each rounding point favor the protocol/counterparty \
consistently, or can a caller pick the side of a round-trip that rounds in \
their favor (e.g. rounding down on both mint and the corresponding burn, when \
one of the two should round the other way to prevent value extraction)?
- Division before multiplication, or any ordering that loses precision it \
didn't have to — especially on integer division where the intermediate \
result truncates.
- Missing or mismatched scaling/decimals — values at different precision \
(e.g. 1e6 vs 1e18, basis points vs raw percentage) combined without a \
conversion factor.
- A formula that doesn't match its intended spec: a term left out (forgetting \
to subtract fees, already-claimed amounts, or accrued interest before \
computing what's remaining/claimable), an operator applied in the wrong \
order, or a value used that should have offset the result but doesn't.
- Under/overflow potential in unchecked blocks, custom fixed-point math, or \
casts between integer sizes — does a wraparound produce an unexpectedly large \
or small result an attacker can exploit?
- Small rounding or truncation errors that compound across many repeated \
operations (per-epoch accrual, per-call fee application) until they produce \
a materially wrong balance or lock funds via a dust remainder that can never \
be fully withdrawn.
- A calculation that silently divides by a value that can legitimately be \
zero, or that assumes a denominator is always positive/nonzero without \
checking.\
""",
)

# --- 4. Temporal State & Staleness --------------------------------------------
TEMPORAL_STALENESS_SYSTEM_PROMPT = """\
You are a senior smart-contract security auditor specializing in temporal \
and staleness bugs — values that should be locked in or re-validated at a \
specific point in time but are read, checked, or reused at the wrong moment.

Two rules you never break:
1. You output ONLY a single JSON object. No prose, no markdown, no code fences \
around it.
2. You never report a bug you cannot back with evidence: an exact location, the \
specific flawed logic, and concrete steps to trigger it.
"""

TEMPORAL_STALENESS_USER_PROMPT_TEMPLATE = _build_user_prompt_template(
    intro="Audit the following codebase, focused on temporal state and "
    "staleness bugs, and report the vulnerabilities you find.",
    what_to_look_for="""\
# What to look for
This pass has one job: find temporal and staleness bugs. Other passes cover \
other bug classes — do not spend effort chasing them here. Within this class, \
be exhaustive.

For every value the code reads and later acts on, ask: can this value change \
between when it is read or validated and when it is actually consumed, and \
does the code silently assume it can't?
- Snapshot vs. live read: a price, rate, or fee that should be captured once \
(at order/listing/position creation) but is instead re-read live at execution \
time — or the reverse, a value that SHOULD track the live market but is \
frozen from an earlier snapshot and never refreshed.
- Validate-then-act gaps: a balance, allowance, ownership, or eligibility \
check performed, followed by one or more external calls or additional steps \
before the checked state is actually used — leaving a window where the \
checked property can change (via reentrancy, a separate transaction, or \
another function) before it's consumed.
- Time- or epoch-based state that isn't synced before use: logic that depends \
on elapsed time (cliffs, vesting schedules, lock expiries, epoch rollovers) \
but a code path reads or writes that state without first updating it to the \
current time, producing a decision based on stale progress.
- Multi-step or multi-transaction flows that implicitly assume nothing else \
in the system changes between the user's first and second call, with no \
re-validation or expiry check at the second step.
- A value cached in local memory/storage at the top of a function that could \
be invalidated by a call made partway through the same function, but is used \
again afterward as if still valid.
- Order-of-operations bugs where an action is permitted based on a condition \
that the action ITSELF then invalidates, but nothing re-checks it (e.g. a \
condition checked before a state-mutating step that changes the very thing \
just checked).
- A global or protocol-level configuration value (a fee, rate, penalty, or \
any other adjustable parameter) that an individual record — an order, a \
position, an agreement, a commitment made by a specific party at a specific \
time — is supposed to lock in at the moment that record is created. When the \
global value changes later, does the existing record keep using the value \
that was in effect when IT was created (a real snapshot, usually a value \
copied into the record's own storage), or does it silently re-read whatever \
the global value happens to be at the moment it's next touched? A party with \
no say in the later change bearing a cost that shifted after they already \
committed is the signature of this bug — trace every such value back to its \
actual read site at the moment it's used, not to where it's declared or \
documented as being set.\
""",
)

# --- 5. Edge Case & Boundary ---------------------------------------------------
EDGE_CASE_BOUNDARY_SYSTEM_PROMPT = """\
You are a senior smart-contract security auditor specializing in edge-case \
and boundary bugs — degenerate inputs, off-by-one conditions, and behavior at \
the exact limits of a valid range or size.

Two rules you never break:
1. You output ONLY a single JSON object. No prose, no markdown, no code fences \
around it.
2. You never report a bug you cannot back with evidence: an exact location, the \
specific flawed logic, and concrete steps to trigger it.
"""

EDGE_CASE_BOUNDARY_USER_PROMPT_TEMPLATE = _build_user_prompt_template(
    intro="Audit the following codebase, focused on edge-case and boundary "
    "bugs, and report the vulnerabilities you find.",
    what_to_look_for="""\
# What to look for
This pass has one job: find edge-case and boundary bugs. Other passes cover \
other bug classes — do not spend effort chasing them here. Within this class, \
be exhaustive.

For every numeric input, array/collection, and time or size parameter, \
mentally test the degenerate and boundary values — zero, one, the maximum \
representable value, an empty collection, and the exact edge of any valid \
range — and check whether the code treats them the same as the "normal" \
middle-of-the-range case. Spend the most effort on the first pattern below \
before moving to the rest — it is the highest-yield one for this pass:
- **An exchange rate, price, or ratio between two different assets/units \
where the smallest expressible step is set by whichever SIDE has FEWER \
decimals**, not by the side that needs fine-grained precision. Find every \
"must be >= 1" or "must be nonzero" check on an integer rate/price and ask: \
1 raw unit of which asset does that floor actually correspond to in real \
terms? If the counted side has few decimals (say, 6 or fewer), that floor of \
"1" can already represent a real-world value far too coarse to price a \
legitimately low-value counterpart asset — the low-decimal side becomes an \
accidental minimum-price wall that silently blocks or badly mis-prices \
anything cheaper than it, even though nothing about the rate calculation \
looks wrong for mid-range values.
- Zero-value inputs: a zero amount, zero address, zero duration, or zero-\
length array that the code doesn't explicitly reject — does it silently \
succeed, produce a free mint or no-op transfer, or divide by zero?
- Off-by-one conditions: `<` vs `<=`, `>` vs `>=` at a range boundary — an \
exact expiry timestamp, an exact cap, an exact whitelist/allowlist count — \
treated inconsistently between the check and the actual limit being \
enforced.
- Unbounded growth: a loop or computation over an array, mapping-derived \
list, or set that grows over time with no cap — does its gas cost or \
behavior break, revert, or become exploitable once the collection is large \
enough (denial of service, or a different code path taken once a length \
threshold is crossed)?
- A rate, share, or per-unit constant derived ONCE by dividing one caller- or \
config-supplied quantity by another (a total split across a count, an amount \
split across a duration or repetition parameter) and then stored and reused \
for that entity's entire remaining lifetime. Don't just check the formula in \
isolation - check what happens when the DIVISOR is set close to, or larger \
than, the DIVIDEND: integer division floors the stored constant to zero \
(silently zeroing or freezing every future payout derived from it, not just \
the current call) or to a value so small the entity's outcome is gutted. \
Because the constant is computed once and persisted, this is a permanent, \
one-shot failure baked in at creation time - not a per-call rounding error \
that stays small - so trace every value that is divided once and stored, not \
just values that are divided repeatedly.
- First-of-its-kind or last-of-its-kind cases: the very first deposit into an \
empty pool/vault, the very last withdrawal that drains it to exactly zero, \
the first or last element of an array being handled by different logic than \
the general case (initialization defaults, a loop's boundary index).
- Maximum-value inputs: a caller-supplied amount, duration, or count at or \
near the type's maximum — does arithmetic on it overflow, wrap, or get \
silently truncated by a downcast?\
""",
)


# --- Registry --------------------------------------------------------------
# The interface other code (the orchestrator/judge) depends on: an iterable
# list of specialist metadata, plus run_specialist(codebase, context, key)
# to execute exactly one of them.
SPECIALISTS: list[dict] = [
    {
        "key": "state_lifecycle",
        "name": "State & Lifecycle Completeness",
        "description": "Multi-step entities whose creation, transition, or "
        "destruction paths fail to keep all their coupled state in sync.",
    },
    {
        "key": "trust_boundary",
        "name": "Trust Boundary & Permissionless Abuse",
        "description": "Functions reachable by the wrong caller, or missing/"
        "inverted/misdirected permission checks.",
    },
    {
        "key": "arithmetic_formula",
        "name": "Arithmetic & Formula Correctness",
        "description": "Rounding, overflow/underflow, and formulas that "
        "don't match their intended economic math.",
    },
    {
        "key": "temporal_staleness",
        "name": "Temporal State & Staleness",
        "description": "Values read, validated, or reused at the wrong "
        "point in time relative to when they should be locked in.",
    },
    {
        "key": "edge_case_boundary",
        "name": "Edge Case & Boundary",
        "description": "Degenerate inputs, off-by-one conditions, and "
        "behavior at the exact limits of a valid range or size.",
    },
]

# key -> (system_prompt, user_prompt_template)
_PROMPTS: dict[str, tuple[str, str]] = {
    "state_lifecycle": (
        STATE_LIFECYCLE_SYSTEM_PROMPT,
        STATE_LIFECYCLE_USER_PROMPT_TEMPLATE,
    ),
    "trust_boundary": (
        TRUST_BOUNDARY_SYSTEM_PROMPT,
        TRUST_BOUNDARY_USER_PROMPT_TEMPLATE,
    ),
    "arithmetic_formula": (
        ARITHMETIC_FORMULA_SYSTEM_PROMPT,
        ARITHMETIC_FORMULA_USER_PROMPT_TEMPLATE,
    ),
    "temporal_staleness": (
        TEMPORAL_STALENESS_SYSTEM_PROMPT,
        TEMPORAL_STALENESS_USER_PROMPT_TEMPLATE,
    ),
    "edge_case_boundary": (
        EDGE_CASE_BOUNDARY_SYSTEM_PROMPT,
        EDGE_CASE_BOUNDARY_USER_PROMPT_TEMPLATE,
    ),
}

# --- Exclusion-loop variant, same derivation Module 2 used for the general
# hunter (agent.EXCLUSION_USER_PROMPT_TEMPLATE): swap the "# Codebase" tail
# for an "already found, don't repeat" section plus the same tail. One
# exclusion template per specialist, built by the same string replace, so a
# specialist's loop reasons over the SAME prompt as its single pass except
# for this one substitution.
_ALREADY_FOUND_TAIL = (
    "# Already found - do not repeat these\n"
    "Earlier passes over this same codebase already reported the findings below. \
Do not report any of them again, even rephrased or with a different title. Look \
at contracts, functions, and guarantees not yet covered by this list.\n\n"
    "{already_found}\n\n"
    "# Codebase\n{codebase}"
)

_EXCLUSION_PROMPTS: dict[str, tuple[str, str]] = {
    key: (system_prompt, user_prompt_template.replace("# Codebase\n{codebase}", _ALREADY_FOUND_TAIL))
    for key, (system_prompt, user_prompt_template) in _PROMPTS.items()
}


def run_specialist(codebase: str, context: str, specialist_key: str) -> list[Finding]:
    """Run one specialist's prompt against the codebase + Module 2's context.

    Mirrors agent.find_bugs_with_context's call/parse/validate pattern exactly:
    one llm.complete call, tolerant JSON extraction, per-item Finding
    validation with malformed entries skipped (not fatal).

    Args:
        codebase: the concatenated .sol source (see codebase.load_codebase).
        context: the output of context.build_context(codebase).
        specialist_key: one of the "key" values in SPECIALISTS.

    Returns:
        A list of `Finding` objects. Findings the model returns in a broken
        shape are skipped rather than crashing the run.

    Raises:
        ValueError: if specialist_key is not a known specialist.
    """
    if specialist_key not in _PROMPTS:
        known = ", ".join(sorted(_PROMPTS))
        raise ValueError(
            f"Unknown specialist_key {specialist_key!r}. Known keys: {known}"
        )

    system_prompt, user_prompt_template = _PROMPTS[specialist_key]
    user_prompt = user_prompt_template.format(codebase=codebase, context=context)

    raw = llm.complete(system_prompt, user_prompt, json_mode=True)

    try:
        data = llm.extract_json(raw)
    except ValueError:
        print("[could not parse the model's reply as JSON — treating as no findings]")
        return []

    if not isinstance(data, dict):
        print("[model reply was not a JSON object — treating as no findings]")
        return []

    findings: list[Finding] = []
    for item in data.get("findings", []):
        try:
            findings.append(Finding(**item))
        except (ValidationError, TypeError) as err:
            print(f"[skipped a malformed finding] {err}")
    return findings


def run_specialist_loop(
    codebase: str, context: str, specialist_key: str, rounds: int = 5
) -> list[Finding]:
    """Run one specialist in a self-excluding loop, same shape as
    agent.find_bugs_loop: each round after the first is told what earlier
    rounds in THIS specialist's own sequence already found, and asked to
    look elsewhere instead of circling back. A specialist's loop only
    excludes its own prior rounds, not other specialists' or the general
    hunter's findings - each lane still reasons independently; only the
    judge sees across lanes.

    Args:
        codebase: the concatenated .sol source (see codebase.load_codebase).
        context: the output of context.build_context(codebase).
        specialist_key: one of the "key" values in SPECIALISTS.
        rounds: how many sequential passes to run.

    Returns:
        The concatenation of every round's findings, in round order.

    Raises:
        ValueError: if specialist_key is not a known specialist.
    """
    if specialist_key not in _PROMPTS:
        known = ", ".join(sorted(_PROMPTS))
        raise ValueError(
            f"Unknown specialist_key {specialist_key!r}. Known keys: {known}"
        )

    system_prompt, plain_template = _PROMPTS[specialist_key]
    _, exclusion_template = _EXCLUSION_PROMPTS[specialist_key]

    all_findings: list[Finding] = []

    for round_no in range(1, rounds + 1):
        already_found = "\n".join(
            f"- {f.title}: {f.description}" for f in all_findings
        )
        if already_found:
            user_prompt = exclusion_template.format(
                codebase=codebase, context=context, already_found=already_found
            )
        else:
            user_prompt = plain_template.format(codebase=codebase, context=context)

        raw = llm.complete(system_prompt, user_prompt, json_mode=True)

        data = None
        try:
            data = llm.extract_json(raw)
        except ValueError:
            print("[could not parse the model's reply as JSON — treating as no findings]")

        if data is not None and not isinstance(data, dict):
            print("[model reply was not a JSON object — treating as no findings]")
            data = None

        before = len(all_findings)
        for item in (data or {}).get("findings", []):
            try:
                all_findings.append(Finding(**item))
            except (ValidationError, TypeError) as err:
                print(f"[skipped a malformed finding] {err}")

        # A full run is ~35 minutes of otherwise-silent API calls, so each
        # lane reports every round it finishes. Six lanes print concurrently;
        # the lane name keeps the lines readable.
        print(
            f"  [{specialist_key}] round {round_no}/{rounds}: "
            f"{len(all_findings) - before} new finding(s)",
            flush=True,
        )

    return all_findings
