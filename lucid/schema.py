"""The shape of a finding.

A free-text answer is hard to trust and impossible to score. So we force the
model to fill in a fixed structure. This `Finding` model is that structure: it
is both the contract we hand the model ("return exactly these fields") and the
validator we run on whatever comes back.

Using pydantic gives us free validation — if the model omits a field or invents
a severity, construction fails loudly instead of poisoning our results.
"""

from typing import Literal

from pydantic import BaseModel, Field

# The impact ladder. Keeping severity to a fixed set makes findings comparable
# and forces the model to commit to how bad each bug is.
Severity = Literal["critical", "high", "medium", "low"]


class Finding(BaseModel):
    """One vulnerability the agent claims to have found.

    Every field earns its place: together they are enough for a human to judge
    the finding without re-reading the whole codebase.

    The model never sees this class; it sees the JSON template in agent.py. This
    schema only validates what comes back — keep the two field lists in sync.

    Note: the per-field descriptions below document the schema for humans. The
    model is guided only by the hand-written JSON template in agent.py, so keep
    the two consistent.
    """

    title: str = Field(description="Short, specific name for the bug.")

    severity: Severity = Field(
        description="Impact level: critical, high, medium, or low."
    )

    location: str = Field(
        description="Where it lives — e.g. 'SecondSwap_Marketplace.sol:212' "
        "or a function name. Be precise enough to find it."
    )

    description: str = Field(
        description="What the bug is: the flawed logic, in plain terms."
    )

    impact: str = Field(
        description="What an attacker gains or what breaks — the 'so what'."
    )

    exploit_steps: list[str] = Field(
        description="Concrete, ordered steps to trigger the bug."
    )
