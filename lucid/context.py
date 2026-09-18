"""Module 2: build a protocol context document before hunting for bugs.

This is a separate LLM pass with a deliberately different persona and task
from `agent.find_bugs`: understand what the protocol is supposed to guarantee,
not look for violations. The output feeds into the hunting agent as background,
closing part of "the intent gap" - reasoning about intent requires a model of
intent to reason from.

Does not touch agent.py's Module 1 SYSTEM_PROMPT/USER_PROMPT_TEMPLATE/find_bugs.
"""

from . import llm

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


def build_context(codebase: str) -> str:
    """Run the context-builder pass over a codebase blob and return the raw text.

    Args:
        codebase: the concatenated .sol source (see codebase.load_codebase).

    Returns:
        A plain-text protocol context document - not JSON, not scored or
        validated. It is meant to be read by a human or fed into the next
        model call, not parsed.
    """
    user_prompt = CONTEXT_USER_PROMPT_TEMPLATE.format(codebase=codebase)
    return llm.complete(CONTEXT_SYSTEM_PROMPT, user_prompt, json_mode=False)
