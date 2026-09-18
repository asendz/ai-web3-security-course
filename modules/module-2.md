---
title: "Give Your AI Agent Context: Closing the Intent Gap in Web3 Security"
description: "Add a protocol-context pass and an exclusion loop to your Module 1 harness - and measure, honestly, whether either one actually raises recall."
slug: "give-your-ai-agent-context"
datePublished: "2026-08-21"
dateModified: "2026-08-21"
author: "Asen"
---

# Give Your AI Agent Context: Closing the Intent Gap in Web3 Security

You just built your first harness, and it caught some real bugs on our benchmark - SecondSwap. 

This module gives it two upgrades: a written-down model of what the protocol is supposed to guarantee, and more than one attempt to use it.

Each matters for its own reason. A model reading raw code can only reason about what the syntax shows it - a guarantee it's never told about is a guarantee it can't check. 

And a single pass, however careful, settles on whatever it notices first; it doesn't come back and look again. 

So this module builds the missing model first - a protocol-context document, produced by a separate pass over the same code - then runs the hunt more than once, each pass told what earlier ones already found, so it keeps looking instead of circling back to the same ground.

The climb we're doing today:

```
Module 1                Hunter Agent -> Findings
Module 2   Context ->   Hunter Agent (looped) -> Findings
```

Get the code - `git checkout module-2` in your existing clone (starting fresh? clone first, see Module 1's Step 0). 

Module 1's `find_bugs` in `agent.py` stays untouched; Module 2 only adds `lucid/context.py` (`build_context`) and two new functions alongside it in `agent.py` (`find_bugs_with_context`, `find_bugs_loop`). Same target, same answer key, same scoring rubric as Module 1.

**Steps at a glance:**

1. **Step 1** - Build a protocol-context document.
2. **Step 2** - Add context to the hunt, and run it in a loop.
3. **Step 3** - What doesn't scale yet.

---

## Step 1 - Build a protocol-context document

The idea is simple: before hunting for bugs, make the model write down what the protocol is *supposed* to do - contract by contract, actor by actor, invariant by invariant - with an explicit instruction not to look for anything wrong yet. 

That output becomes important context for the actual hunt.

<details>
<summary>Show the full context-building prompt, exactly as it ships in the repo</summary>

```python
CONTEXT_SYSTEM_PROMPT = """\
You are a smart-contract protocol analyst. Your job is to read Solidity source \
and build an accurate, structured mental model of what the protocol is \
supposed to do and guarantee - not to look for bugs or vulnerabilities.

Two rules you never break:
1. Describe intended behavior only, as the code defines it. Do not speculate \
about what might go wrong.
2. Be specific: name the actual contracts, functions, and state variables \
involved in each guarantee you describe.
"""

CONTEXT_USER_PROMPT_TEMPLATE = """\
Read the following codebase and produce a structured summary with one section \
per contract.

For each contract, describe:
- Role: what this contract is responsible for in the protocol.
- Actors: who calls into it (other contracts, or off-chain roles - owner, \
user, etc.) and what trust level each actor has.
- Invariants: the specific conditions that must always hold - state \
relationships that should never become inconsistent, ordering guarantees, \
conservation properties (e.g. "total allocated across all vestings for a \
beneficiary should never exceed the tokens actually held").
- Dependencies: which other contracts in this codebase it calls into or is \
called by, and what it assumes about their state when it does.

Do not list bugs, risks, or recommendations. Describe only what the code is \
designed to guarantee.

# Codebase
{codebase}
"""
```

</details>

`build_context` is one function, one call, no schema to validate against - the output is prose, meant to be read, not parsed:

```python
def build_context(codebase: str) -> str:
    user_prompt = CONTEXT_USER_PROMPT_TEMPLATE.format(codebase=codebase)
    return llm.complete(CONTEXT_SYSTEM_PROMPT, user_prompt, json_mode=False)
```

Here's a real excerpt from an actual run - condensed for space, substance unchanged - of what comes back for one contract:

> **`SecondSwap_Marketplace`**
>
> **Role.** Manages secondary-market listings for vesting allocations. Creates listings through `listVesting`, holds listing metadata in `listings[vestingPlan][listingId]`, validates and executes purchases through `spotPurchase`... Completes the corresponding vesting transfer through `SecondSwap_VestingManager`.
>
> **Actors.** Seller/user - calls `listVesting`... Buyer/user - calls `spotPurchase`, must satisfy listing status, amount, whitelist, and referral rules... Marketplace administrator - the address returned by `IMarketplaceSetting(marketplaceSetting).s2Admin()`...

Nothing about bugs. Just a model of who does what and what has to stay true. This is the piece Module 1 never had.

---

## Step 2 - Add context to the hunt, and run it in a loop

We changed two things in Module 1's hunting prompt: added a **"Protocol context"** section before the severity ladder, and reworded "How to work" to reason about *invariants* ("for each invariant in the context above: is there a path through the code that breaks it?") instead of per-contract framing - with one added line telling the model to check cross-contract invariants. 

Everything else - severity floor, evidence discipline, coverage instruction - stays byte-for-byte the same. That's `CONTEXT_AWARE_USER_PROMPT_TEMPLATE` in `lucid/agent.py`; `find_bugs_with_context(codebase, context)` calls it the same way Module 1's `find_bugs` calls the original.

<details>
<summary>Show the full context-aware prompt, exactly as it ships in the repo</summary>

```python
CONTEXT_AWARE_USER_PROMPT_TEMPLATE = """\
Audit the following codebase and report the vulnerabilities you find.

# Protocol context
Another pass already read this codebase and built the context below — what \
each contract is supposed to guarantee, who the trusted actors are, and what \
invariants must hold. Use it to reason about intent, not just syntax: a \
violation of one of these invariants is exactly the kind of bug worth \
reporting.

{context}

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
Think step by step BEFORE you answer. Silently, for each invariant in the \
context above: is there a path through the code that breaks it? Check the \
invariants that span more than one contract especially closely — those are \
the ones a single-file reading misses. Do this reasoning internally. Do NOT \
include it in your output.

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
```

</details>

Try it yourself: `python -m lucid.run --context` runs `build_context` then one context-aware hunt, printed to your terminal exactly like Module 1's plain run.

Adding just the context document - no loop yet - raised average recall modestly.

What it did do that the loop alone can't take credit for: it caught **H-01 and H-02**, in 2 of 4 runs, after all four of Module 1's context-free runs missed both. 

The obvious next lever: run it more than once, and make each pass look somewhere new. 

The mechanism, in short: `find_bugs_loop(codebase, context, rounds=5)` runs the same context-aware prompt as `find_bugs_with_context`, five times in sequence - but starting with round two, it tells the model what every earlier round in this sequence already reported and asks it to look elsewhere instead of circling back to the same ground:

```
# Already found - do not repeat these
Earlier passes over this same codebase already reported the findings below.
Do not report any of them again, even rephrased or with a different title. Look
at contracts, functions, and guarantees not yet covered by this list.

{already_found}
```

Everything else stays exactly as it was above - one context-building call plus five hunting rounds, each round's prompt a little larger than the last since it carries every prior round's findings. 

Measured, one full sequence: **~$0.13**, against Module 1's roughly 5-10 cents for a single pass.

Try it yourself: `python -m lucid.run --loop` (or `--loop 3` for a shorter run).

Five independent sequences of five rounds each, same target, same scoring:

| Sequence | EXACT | PARTIAL | Weighted recall |
|---|:---:|:---:|:---:|
| 1 | 5 | 3 | 28.3% |
| 2 | 6 | 1 | 28.3% |
| 3 | 7 | 3 | 37.0% |
| 4 | 7 | 2 | 34.8% |
| 5 | 7 | 2 | 34.8% |

Raw findings for all five sequences: [`m2-loop-1.json`](https://github.com/asendz/ai-web3-security-course/blob/master/target/runs/m2-loop-1.json) through [`m2-loop-5.json`](https://github.com/asendz/ai-web3-security-course/blob/master/target/runs/m2-loop-5.json).

Mean **32.6%**, range 28.3%-37.0%. **H-01, H-02, H-03, and M-19 landed as EXACT in every single sequence** - the loop didn't just add variance, it made the context pass's one big unlock (H-01/H-02) reliable rather than a coin flip. 

Past those four, coverage genuinely varies - no two sequences caught the same additional set, and even the best (seq3, 10 of 23 GT IDs, weighted 8.5/23) still missed 13 outright. 

---

## Step 3 - What doesn't scale yet

A few notes from this module that you should keep in mind:

- **One hunter, run many times - not many angles.** The loop tells the model not to repeat its own prior findings, but it's still the same reasoning lens every round, just steered away from its own earlier answers. It never looks at the code through a genuinely different angle the way Module 3's specialists do - so a blind spot this lens has stays its blind spot, round after round.
- **The context document is trusted, not checked.** `build_context` runs once, and every hunting round treats its output as ground truth. If it mischaracterizes an invariant, or misses one entirely, every round downstream inherits that blind spot silently - nothing here catches a wrong context document, only a wrong hunt.
- **False positives slip through, unchecked.** About 10% of Step 2's output was a confident, well-formatted finding with no real bug behind it - the same one, recurring. A one-line prompt exclusion would catch it cheaply. 

None of these are fixed in this module's code. Module 3 addresses the single-angle problem with specialist lenses reasoning in parallel, and the false-positive problem with a judge; the context-document problem stays open even there.

---

## What you built

Measured honestly:

- Single context-aware pass: **16.85%** average recall per run - and the first-ever appearance of H-01/H-02.
- Context + 5-round exclusion loop: **32.6%** average recall per sequence - with H-01/H-02/H-03/M-19 now landing as EXACT in every sequence.
- Cost: **~$0.13** a sequence - a few cents more than Module 1's single pass, for more than double the per-run recall.

You now have a harness that doesn't just read code cold - it builds a model of what the code is supposed to guarantee, then hunts against that model more than once. H-01 and H-02 - invisible to Module 1 - now land as EXACT every time.

You're two modules in. Module 3 is next.

---

## Reference

- [`lucid/context.py`](https://github.com/asendz/ai-web3-security-course/blob/master/lucid/context.py) - the context-builder pass.
- [`lucid/agent.py`](https://github.com/asendz/ai-web3-security-course/blob/master/lucid/agent.py) - `find_bugs_with_context` and `find_bugs_loop`, additive to Module 1's `find_bugs`.
- [`target/GROUND_TRUTH.md`](https://github.com/asendz/ai-web3-security-course/blob/master/target/GROUND_TRUTH.md) - same answer key as Module 1.
- [`target/runs/m2-run-1.json`](https://github.com/asendz/ai-web3-security-course/blob/master/target/runs/m2-run-1.json) through `m2-run-4.json` - the four context+hunt runs behind Step 2's numbers.
- [`target/runs/m2-loop-1.json`](https://github.com/asendz/ai-web3-security-course/blob/master/target/runs/m2-loop-1.json) through `m2-loop-5.json` - the five loop sequences behind Step 2's table.

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "TechArticle",
      "headline": "Give Your AI Agent Context: Closing the Intent Gap in Web3 Security",
      "description": "Add a protocol-context pass and an exclusion loop to your Module 1 harness - and measure, honestly, whether either one actually raises recall.",
      "author": {"@type": "Person", "name": "Asen"},
      "datePublished": "2026-08-21",
      "dateModified": "2026-08-21"
    },
    {
      "@type": "HowTo",
      "name": "Give an AI security agent protocol context and measure the recall effect",
      "step": [
        {"@type": "HowToStep", "name": "Step 1 - Build a protocol-context document", "text": "A separate pass reads the codebase and writes down each contract's role, actors, invariants, and dependencies - without hunting for bugs."},
        {"@type": "HowToStep", "name": "Step 2 - Add context to the hunt, and run it in a loop", "text": "A single context-aware pass raised average recall from 14.65% to 16.85% across four runs and found a cross-contract bug class (H-01/H-02) all four of Module 1's context-free runs missed; a 5-round exclusion loop on top of that raised average recall to 32.6% per sequence, with H-01/H-02/H-03/M-19 landing as EXACT in every sequence."},
        {"@type": "HowToStep", "name": "Step 3 - What doesn't scale yet", "text": "Three honest gaps in this module's design: one hunter reasoning the same way every round instead of many angles, a context document that's trusted but never checked, and a recurring false positive that slips through about 10% of the time unless you add a prompt exclusion yourself."}
      ]
    }
  ]
}
</script>
