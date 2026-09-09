"""Smoke test: prove your setup can reach a model before running a full scan.

    python -m lucid.check

It loads .env (via the package import), checks your key and base URL, shows
which model is configured, and makes one tiny real call. If anything is off it
says exactly what to fix in one line - not a traceback.
"""

import os

from . import llm  # importing the package runs load_dotenv() in __init__


def main() -> None:
    key = os.environ.get("OPENAI_API_KEY")
    base = os.environ.get("OPENAI_BASE_URL")

    if not key:
        print("OPENAI_API_KEY is not set. Copy .env.example to .env and add your key (see Step 0 - Set up your environment and get an API key).")
        return

    print(f"key:   set ({key[:6]}...)")
    print(f"base:  {base or 'api.openai.com (no OPENAI_BASE_URL set)'}")
    print(f"model: {llm.MODEL}")

    print("\nCalling the model...")
    try:
        reply = llm.complete("You are a helpful assistant.", "Reply with exactly: ready", json_mode=False)
    except Exception as err:  # noqa: BLE001 - we want a friendly one-liner, not a trace
        msg = str(err)
        if "model_not_found" in msg or "does not exist" in msg or "model not found" in msg.lower():
            print("  model_not_found: the MODEL id in lucid/llm.py is not one your provider serves.")
            print("  Swap it for a real model (keep OPENAI_BASE_URL if you route through a gateway).")
        else:
            print(f"  call failed: {msg}")
        return

    print(f"reply: {reply.strip()!r}")
    if "ready" in reply.lower():
        print("\nAll set - key, base URL, and model all resolve.")
    else:
        print("\nGot a reply, so the chain resolves - the exact text just varied.")


if __name__ == "__main__":
    main()
