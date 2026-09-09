"""Minimal LLM client.

This is the thinnest possible wrapper around a chat model. The whole point of
the course is that YOU own the harness, so we keep the provider layer tiny and
readable: one function to call the model, one helper to parse its reply.

The model is OpenAI-compatible, so we use the `openai` SDK. To swap models,
change the one line marked below (and the base URL if your provider differs).
"""

import json
import os
import re

from openai import OpenAI

# The model we call. It is OpenAI-compatible, so any provider that speaks the
# same API works. Swap this one string to change models — that is the whole
# "model-agnostic" promise: swap the model, keep the method.
# Setting OPENAI_BASE_URL (see .env.example) routes this model through an
# OpenAI-compatible gateway, so the same code works with any such provider.
# This is a real, public model — the one the baseline in this course was
# actually run with, through the Requesty gateway (see .env.example).
MODEL = "openai/gpt-5.6-luna"


def _client() -> OpenAI:
    """Build the API client, reading the key from the environment.

    We never hard-code a key. It comes from OPENAI_API_KEY (see .env.example).

    If you point lucid at a non-OpenAI but OpenAI-compatible provider, set
    OPENAI_BASE_URL too and the client routes there instead of api.openai.com.
    """
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "OPENAI_API_KEY is not set. Copy .env.example to .env and add your "
            "key there — run.py loads .env automatically on startup."
        )
    base_url = os.environ.get("OPENAI_BASE_URL")
    if base_url:
        return OpenAI(api_key=api_key, base_url=base_url)
    return OpenAI(api_key=api_key)


def complete(system: str, user: str, json_mode: bool = True) -> str:
    """Send one system + one user message to the model and return the reply text.

    Args:
        system:    the standing instructions (who the model is, how to answer).
        user:      the actual request (here: the code to audit).
        json_mode: if True, ask the API to return strict JSON (JSON mode). This
                   makes parsing far more reliable than free-form text.

    Returns:
        The raw text of the model's reply. Parsing is a separate step so the
        caller can decide what to do with it.
    """
    client = _client()

    # Build the call arguments. JSON mode tells the API "the reply MUST be a
    # valid JSON object", which removes a whole class of parsing headaches. Not
    # every model supports it, so it stays optional — and we only add the
    # response_format key when we actually want it. Passing response_format=None
    # trips up some OpenAI-compatible gateways, so we leave it out entirely.
    kwargs = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        # A low but non-zero temperature. Pure greedy decoding (temperature=0)
        # can fixate on a locally-confident reasoning path and repeat itself;
        # a small amount of randomness lets the model consider a close-second
        # token instead. And the API isn't fully deterministic at 0 anyway
        # (provider-side batching and routing add their own variance), so
        # we may as well pick the value that's kindest to reasoning quality,
        # not the one that merely looks stable.
        "temperature": 0.3,
        # gpt-5.6-luna is a reasoning model: it thinks before it answers, and
        # this dial controls how much. "high" spends more of that thinking
        # budget — worth it here, since auditing a whole codebase in one pass
        # is exactly the kind of task that rewards more deliberation, not
        # less. (On some reasoning models, temperature is quietly ignored
        # once reasoning_effort is set — we send both and let the API sort
        # it out rather than guess which one it honors.)
        "reasoning_effort": "high",
    }
    if json_mode:
        kwargs["response_format"] = {"type": "json_object"}

    completion = client.chat.completions.create(**kwargs)

    # If the model hit its output-token limit, the reply is cut off mid-JSON and
    # will fail to parse. Say so plainly instead of letting a confusing parse
    # error surface downstream.
    if completion.choices[0].finish_reason == "length":
        raise RuntimeError(
            "The model's reply was truncated (it hit the output-token limit), "
            "so the JSON is incomplete. Try a smaller target or fewer files."
        )

    return completion.choices[0].message.content or ""


# A code fence looks like ```json ... ``` or ``` ... ```. We strip it if present.
_FENCE = re.compile(r"^```(?:json)?\s*|\s*```$", re.IGNORECASE)


def extract_json(text: str) -> dict:
    """Parse a JSON object out of a model reply, tolerantly.

    Even in JSON mode a model can wrap its answer in a code fence or add a stray
    sentence before the braces. This helper handles the common cases:

      1. the reply is already clean JSON,
      2. the reply is wrapped in a ```json ... ``` fence,
      3. there is preamble/trailing text around a single {...} object.

    Returns the parsed dict, or raises ValueError if nothing parses.
    """
    text = text.strip()

    # Case 1: try it as-is first.
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Case 2: strip a surrounding code fence and retry.
    unfenced = _FENCE.sub("", text).strip()
    try:
        return json.loads(unfenced)
    except json.JSONDecodeError:
        pass

    # Case 3: grab the outermost {...} span and parse that. This rescues replies
    # that have chatter before or after the object.
    start = unfenced.find("{")
    end = unfenced.rfind("}")
    if start != -1 and end != -1 and end > start:
        candidate = unfenced[start : end + 1]
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass

    raise ValueError(f"Could not parse JSON from model reply:\n{text[:500]}")
