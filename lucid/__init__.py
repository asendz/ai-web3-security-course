"""lucid - a small, own-it-yourself harness for AI bug hunting.

Importing the package loads .env, so every entry point sees your OPENAI_API_KEY
without extra setup - `python -m lucid.run`, `python -m lucid.check`, or a bare
`from lucid import llm` in a REPL all pick it up the same way.
"""

from dotenv import load_dotenv

load_dotenv()
