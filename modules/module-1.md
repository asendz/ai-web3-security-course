---
title: "How to Start with AI in Web3 Security: Build Your First Bug-Hunting Agent"
description: "Build your first AI bug-hunting agent for web3 - wrap a model in Python, scan real Solidity, and score it against a Code4rena answer key."
slug: "build-your-first-ai-security-agent"
datePublished: "2026-08-18"
dateModified: "2026-09-10"
author: "Asen"
---

# How to Start with AI in Web3 Security: Build Your First Bug-Hunting Agent
This is Module 1 of **AI for Web3 Security - Zero to Hero**. We're building, from scratch, an AI system that finds smart contract vulnerabilities.

Four modules total, each one adding a piece. By the end of this module you'll have your own AI agent, tested against **SecondSwap** - a real vested-token marketplace that ran as a public [Code4rena audit contest](https://github.com/code-423n4/2024-12-secondswap).

No coding background required - Claude Code can write the Python with you, or you can clone the finished agent and read it.

The climb, as a system diagram - one piece added per module:

```
Module 1   Hunter Agent -> Findings
Module 2   Context -> Hunter Agent (looped) -> Findings
Module 3   Context -> Hunter Agents (specialized) -> Judge -> Findings

Module 4   measured from the outside:
           Findings + Ground Truth -> Recall -> improve -> re-run
```

Today we build the first row.

The **Hunter Agent** is one prompt, one model call. Hand it a codebase, it reasons over it once, hands back structured findings. No extra context, no judge, no orchestration.

By the last module you'll have a harness that's effective, efficient, and measured - one you can keep improving after the course ends.

We're building from scratch instead of using a framework or a Claude Code skill, for two reasons: we want it model-agnostic, and we want to own the whole thing end to end. A Claude skill only runs inside Claude - change the model and it breaks. Code you own doesn't have that problem.

Let's get started.

**Steps at a glance for this module:**

1. **Step 0** - Set up your environment and get an API key.
2. **Step 1** - Build a structured AI security agent.
3. **Step 2** - Scan a whole protocol in one pass.
4. **Step 3** - How many bugs does one AI agent find? (an honest range, not one lucky number)
5. **Step 4** - What one agent misses.

Before you start: consider setting Claude up as a tutor while you work through this, not just a coding partner. Paste this into Claude Code once, at the start:

> You're helping me work through "AI for Web3 Security: Zero to Hero," a hands-on course where I'm learning to build my own AI security harness in Python, module by module. Right now I'm on Module 1, working with `lucid` - a single-agent system that reads Solidity and returns structured findings.
>
> Whether I ask you to explain existing code or help me write new code, don't just hand me an answer. Explain the reasoning first, keep code small and heavily commented, and ask me questions to check I understand before moving on.
>
> The rule for this course: I own the harness, so favor explaining over just producing working code - but trust me to say when I've got it and I'm ready to move on.

---

## Step 0 - Set up your environment and get an API key

The Python package we're building is called `lucid`.

You'll need a terminal, Python, and a funded API key for an OpenAI-compatible model - exact versions live in [the README](../README.md). Your key needs a small prepaid balance before it works.

```bash
git clone https://github.com/asendz/ai-web3-security-course
cd ai-web3-security-course
git checkout module-1
```

_If `git checkout module-1` fails, you're likely already on the right branch - keep going._

Once you're in, point Claude at a file - "explain `lucid/llm.py` to me, short and simple" - and don't move on until you could explain it yourself.

Get an API key from any provider that uses the OpenAI API - OpenAI directly, or a gateway like [Requesty](https://www.requesty.ai/) or [OpenRouter](https://openrouter.ai/) that gives you access to more models through one key.

### Install

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env    # then paste your key into OPENAI_API_KEY
```

Not using plain OpenAI? Also set `OPENAI_BASE_URL` in `.env` to your provider's endpoint - `.env.example` ships with Requesty's filled in. Windows activation and `python` vs `python3` aliasing live in [the README](../README.md). The key stays in `.env`, never in code and never in git.

### Confirm it works

```bash
python -m lucid.check
```

It checks your key and base URL, prints the configured model, then makes one live call and shows you the reply. A clean `ready` means you're wired up end to end.

---

## Step 1 - Build a structured AI security agent

Paste a contract into a chatbot and ask it to "find the bugs," and you'll get something fluent back - confident, shaped like a security review, and useless as a system. Unranked. Unaccountable. Impossible to compare run to run.

Somewhere in that reply, buried as a hedge, there might be a real signal: "the discount applied at purchase might not be capped, so a seller could end up paying out more than the listing allows." That's a genuine lead on a real bug. A naive prompt can't tell it apart from the three invented nits sitting next to it.

We want a structured system instead - the reasoning above, minus the guesswork. The job of this step is making one prompt structured enough to carry that weight.

Four disciplines do the work.

### Role and priorities

The model needs to know who it is and what counts. An auditor hunts fund-loss; a linter hunts style.

So we give it a role and an explicit impact ladder: critical is direct theft or permanent fund-locking, high is fund loss under a reachable condition or a broken invariant, medium is narrower value leakage or mis-accounting. Below that floor - style, gas nits, Low-severity edge cases - we tell it to stop looking, and never invent bugs to fill space.

This is what saves the discount lead. An uncapped discount that lets a buyer drain more value than intended is High by definition, so the model ranks it at the top instead of next to a NatSpec nit. Impact-first framing is the single biggest lever on quality - it's the intent gap made operational: a model told to reason about *guarantees* instead of *patterns* looks in the right place.

### Reason internally, answer in JSON

We want the model's full reasoning and none of its rambling. So we split them: think step by step first, silently - what is this contract supposed to guarantee, who's trusted, where does value move, where does the code contradict its own intent - then return only a JSON object.

This is where the hedge dies. Instead of "might not be capped," the model works out exactly which check is missing and how value moves as a result - and says so cleanly.

### Evidence discipline

This is the one that kills hallucination, and it starts before the model runs: `lucid` prefixes every source line with its real line number, so a citation like `SecondSwap_StepVesting.sol:230` points at a line you can actually check, not one the model invented.

Then we require, for every finding: a precise location, the flawed logic, the concrete impact, ordered steps to trigger it. The discount hedge either becomes a precise location, the exact missing check, a concrete impact, and ordered exploit steps - or it gets dropped. 

### A fixed schema

Finally, we pin the output shape in code. We want a "finding" to be a validated object.

```python
class Finding(BaseModel):
    title: str
    severity: Severity          # Literal["critical","high","medium","low"]
    location: str
    description: str
    impact: str
    exploit_steps: list[str]
```

The discount lead finishes its journey here: a fluent hedge becomes a validated `Finding` - severity assigned, location cited, evidence attached. Four disciplines, one vibe turned into one checkable bug.

The agent lives in `lucid/agent.py` - the four disciplines rendered as a system prompt, a user prompt, and a validation loop. The exact text ships in the repo.

<details>
<summary>Show the full prompt, exactly as it ships in the repo</summary>

```python
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
```

</details>

Notice how directly each piece maps to a discipline above: the impact ladder is Discipline 1, "think step by step... do NOT include it in your output" is Discipline 2, the evidence-discipline bullets are Discipline 3, the JSON shape is Discipline 4.

The `find_bugs` function is the entire agent: prompt in, JSON out, validated.

One malformed entry doesn't throw away the good ones. That's the harness doing its job.

---

## Step 2 - Scan a whole protocol in one pass

But real protocols are many files that only make sense together - and the bugs that matter live in the seams between them.

The simplest move: give the model everything at once. Frontier models have big context windows - a small protocol fits in one prompt. That's what we're going to do in `lucid/codebase.py`.

`// FILE:` markers mark where each file starts. Line numbers make every citation verifiable. A size guard stops you from silently firing an over-limit prompt.

**SecondSwap** has 23 known findings in its public answer key: 3 High and 20 Medium. We scan this same codebase every module, so you can watch the detection curve climb.

> **Before you run.** `python -m lucid.check` is tiny and near-free. A full `lucid.run` is one large call - about 25,000 tokens in, a few hundred out, roughly 5-10 cents on the model this course ships with.

```bash
python -m lucid.run
```

The loader pulls in all seven in-scope contracts plus interfaces - about 93,576 characters of Solidity - and hands the whole blob to the agent in one call. Load the codebase, run the agent, print the findings, and let's take a look at what we catch.

Want to build `lucid` yourself instead of cloning it? Copy the plumbing as-is from the repo (`run.py`, `check.py`, `__init__.py`, `requirements.txt`, `.env.example`, everything under `target/`). The four idea files - `llm.py`, `schema.py`, `codebase.py`, `agent.py` - you can build with Claude Code instead, using Steps 1-2 as the spec:

<details>
<summary>Build lucid yourself - one prompt for all four files</summary>

> I'm working through Module 1 of "AI for Web3 Security: Zero to Hero," a hands-on course where I build my own AI security harness in Python. I want to build `lucid` - a small package with four files - myself instead of just cloning it: `llm.py` (a minimal OpenAI-compatible client with `complete()` and `extract_json()`), `schema.py` (a pydantic `Finding` model), `codebase.py` (`load_codebase(path)`, which reads every `.sol` file under a directory into one line-numbered string), and `agent.py` (the Hunter Agent - a system prompt, a user prompt template, and a `find_bugs(codebase)` function).
>
> Build these with me one at a time, using the module's own explanation of each file's job as the spec - I'll share the relevant section as we go. Explain your reasoning first, keep the code small and commented, and check I understand before moving to the next file - don't just hand me finished code.

</details>

---

## Step 3 - How many bugs does one AI agent find?

We ran the finished harness against SecondSwap four separate times and scored every single one.

> **How these runs were produced.** Four representative, unedited passes, saved in [`target/runs/run-1.json`](../target/runs/run-1.json) through [`run-4.json`](../target/runs/run-4.json) so you can check the table against the exact findings scored. Runs vary at temperature 0.3, so yours won't match these line for line.

> **How matches are scored.** For each ground-truth bug, ask: does any of our findings name the same root-cause defect - the same specific thing wrong in the code, not just the same file or function - and would our fix actually eliminate it? Same root cause + same fix = **EXACT**. Same root cause but a narrower, different, or missing fix (or a severity gap of two levels or more) = **PARTIAL**. Different root cause entirely = **MISS**, even if it's one function away. Same bar real audit tooling gets graded on - not one invented for this article. (✅ EXACT · ◐ PARTIAL · – MISS. Try it yourself in the callout at the end of this section.)

| Ground truth | Run 1 | Run 2 | Run 3 | Run 4 | Verdict |
|---|:---:|:---:|:---:|:---:|:---:|
| **H-03** - incorrect `releaseRate` | ✅ | ✅ | ✅ | ✅ | EXACT |
| **H-01** - listing order affects claimable amounts | – | – | – | – | MISS |
| **H-02** - `transferVesting` creates incorrect vesting for buyers | – | – | – | – | MISS |
| **M-01** - inverted listing-type validation | – | – | – | – | MISS |
| **M-14** - incorrect referral fee math | ✅ | ✅ | ✅ | ✅ | EXACT |
| **M-19** - large step counts cause fund loss | ✅ | ✅ | ✅ | – | EXACT |
| **M-17** - uneven vesting from `stepDuration` rounding | – | – | ✅ | ✅ | EXACT |
| **M-06** - `stepsClaimed` underflow blocks claims | – | – | – | ◐ | PARTIAL |
| **M-02** - discounted listings unpurchasable | – | ◐ | – | ◐ | PARTIAL |
| off-catalog (real bugs, not in the 23) | Sybil-fillable whitelist | decimals overflow | – | fee-on-transfer token | - |

Across all four runs combined: **4 of 23 EXACT, 2 more PARTIAL, 17 MISS** - a weighted recall (EXACT = 1, PARTIAL = 0.5) of **5 of 23, about 22%**. That's the honest number for one agent, four tries, no judge, no orchestration.

Two config details behind that number: the model (`gpt-5.6-luna`, routed through Requesty) is one string in `llm.py` - **swap the model, keep the method.** And `llm.py` sets `reasoning_effort: "high"`: `gpt-5.6-luna` is a reasoning model, and auditing a whole codebase in one pass rewards more deliberation, not less.

It missed **M-01** every single time - an inverted operator, `!=` where the code meant `==`. The easiest bug in the whole set. Four runs, four misses, making it a confirmed blind spot that we'll address later.

Every run reports several findings across several contracts - breadth of output was never the problem. Breadth of *attention* is: the same handful of bugs dominates run after run regardless.

> **One agent is powerful but unsystematic.** It reliably catches the loudest bug in the set, every single time, and just as reliably misses its quiet neighbor, every single time - because nothing forces it to keep checking every guarantee once it has settled on a satisfying story for the loudest one.

5 of 23 isn't the ceiling of AI security. It's the floor - the honest starting line.

> **Score it yourself.** You don't need special tooling to check this table - the same question, asked once over everything instead of pair by pair, does the job. Hand a model the full ground-truth list and one run's findings, and ask it to score every pair at once.

<details>
<summary>Show the scoring prompt</summary>

```
Ground-truth bugs: {paste the full list from GROUND_TRUTH.md}
Our findings: {paste the full findings array from one run JSON}

For each ground-truth bug, find the strongest matching finding (if any) and
reason about the underlying CODE DEFECT, not surface wording - two findings
mentioning the same function can be different bugs, and two findings using
different words can be the same bug. Read the actual .sol source when the
one-line descriptions alone don't settle it.

Score each ground-truth bug:
- EXACT: same defect, same fix.
- PARTIAL: same defect, but our fix is narrower, different, or missing -
  or our finding's severity differs from the ground truth's by two or
  more levels.
- MISS: no finding names the same defect.

Return one row per ground-truth bug: id, verdict, and a one-sentence
justification naming which finding (if any) it matched.
```

</details>

Run it against your own harness's output and compare for yourself.

---

## Step 4 - What one agent misses

Look at *why* it missed them. Each reason names a capability we haven't built yet.

- It missed easy bugs even when told to check everything. Every run reports several findings, but the same salient handful, not the full 23 - because nothing forces **systematic coverage** of every guarantee equally.
- It can't tell you which findings are real. There's **no judge** - a true High and a confident hallucination look the same.

Those two gaps are the next two modules, in order:

- **Module 2 - context, run in a loop** _(coming next)_. Real protocol context, plus passes that hunt for what earlier ones missed.
- **Module 3 - an orchestrated harness, L3** _(coming soon)_. Specialist lenses, each hunting one class of bug, fanned across the protocol and synthesized - the fix for "unsystematic."

The jump that matters is L2 to L3: one clever agent becoming an orchestrated system with judgment. You're on the L2 side of that line - a working agent, and a number that proves where the edge is.

---

## What you built

You own a real harness end to end: `llm.py` talks to the model, `codebase.py` feeds it the code, `schema.py` pins the output, `agent.py` is the reasoning agent, `run.py` drives it.

More than the code, you built the instinct that separates practitioners from tutorial-followers. You didn't trust the output - you *checked* it, mapped it to ground truth, and looked straight at what it missed.

That's L2. It confirms a few. Read `lucid`'s findings against [`target/GROUND_TRUTH.md`](../target/GROUND_TRUTH.md) when you're ready to see the whole answer key.

You're not late to AI for web3 security. You just built your first harness.

---

## Reference

Everything below is reference material, not more of the story: the structured data for search engines.

<!-- Structured data for search and AI answer engines. Emitted here because the .md ships without a build pipeline; move to the render layer if one is added. -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "TechArticle",
      "headline": "How to Start with AI in Web3 Security: Build Your First Bug-Hunting Agent",
      "description": "Build your first AI bug-hunting agent for web3 - wrap a model in Python, scan real Solidity, and score it against a Code4rena answer key.",
      "author": {"@type": "Person", "name": "Asen"},
      "datePublished": "2026-08-18",
      "dateModified": "2026-09-10"
    },
    {
      "@type": "HowTo",
      "name": "Build your first AI bug-hunting agent for web3 security",
      "description": "Build a single-agent (L2) smart-contract security harness in Python and measure its recall against a real Code4rena answer key.",
      "step": [
        {"@type": "HowToStep", "name": "Step 0 - Set up your environment and get an API key", "text": "Clone the repo, install Python 3.10+ with pip and git, fund an OpenAI-compatible key, and confirm the model resolves with the smoke test."},
        {"@type": "HowToStep", "name": "Step 1 - Build a structured AI security agent", "text": "See why a naive prompt is unranked and unaccountable, then add four disciplines: an impact-first role, reason-then-JSON, evidence discipline, and a fixed pydantic schema."},
        {"@type": "HowToStep", "name": "Step 2 - Scan a whole protocol in one pass", "text": "Load every in-scope contract into one prompt and run the single agent over the full codebase in one pass."},
        {"@type": "HowToStep", "name": "Step 3 - How many bugs does one AI agent find? (an honest range, not one lucky number)", "text": "Run the agent multiple times and score each finding against a real answer key by root cause and fix: 4 of 23 exact, 2 more partial, a weighted recall of about 22% across four runs - with one easy bug and two quiet sibling bugs missed every time."},
        {"@type": "HowToStep", "name": "Step 4 - What one agent misses", "text": "Identify the missing capabilities - systematic coverage and a judge - which the next two modules add."}
      ]
    }
  ]
}
</script>
