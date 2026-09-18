# AI for Web3 Security: Zero to Hero

A hands-on course that takes you from *"how do I start with AI in web3 security?"*
to building, measuring, and improving your own AI bug-hunting harness around a
frontier model.

You don't get a finished tool. You become someone who builds and improves these
systems — and who keeps going long after the last module.

## The arc

Same target codebase (SecondSwap) scanned across all four modules. The detection
curve climbs from *a few* bugs to *most*.

- **Module 1 — your first harness.** One reasoning agent → structured findings.
  Honest baseline on the target: catches a few.
- **Module 2 — context + loop.** A protocol-context pass plus an exclusion
  loop that tells each round what earlier rounds already found.
- **Module 3 — an orchestrated harness.** Five specialist agents plus the
  general hunter, run in parallel, and a judge that checks every finding
  against the code. Catches more than half.
- **Module 4 — a measured harness + the launchpad** _(coming next)_. Recall against ground truth,
  honestly, plus the self-improvement loop handed over as a transferable method.

## The tool you build: `lucid`

One Python package that grows a module at a time. Built on the raw model API —
for pedagogy (learn the primitives), determinism (code doesn't improvise), and
ownership (you own the wrapper).

## Layout

- `lucid/` — the harness you build, module by module.
- `target/` — the SecondSwap contracts under test (constant across modules).
- `modules/` — the per-module build guides.

## Setup

```bash
python3 -m venv .venv          # some systems alias this as `python`
source .venv/bin/activate      # macOS / Linux
# .venv\Scripts\activate       # Windows (PowerShell or cmd)
pip install -r requirements.txt
cp .env.example .env           # then paste your API key (the gateway URL is pre-filled)
```

Get an API key from [Requesty](https://requesty.ai) (the OpenAI-compatible
gateway the base URL is pre-filled for) and paste it into `OPENAI_API_KEY`.

Examples use Python and an OpenAI-compatible model. The `MODEL` shipped in
`lucid/llm.py` (`gpt-5.6-luna`) is a real, public model, routed through
Requesty - it's what produced this course's baseline runs. Leave it as-is,
or swap in whatever's sharpest when you read this; either way, nothing needs
replacing before it runs. `.env.example` ships with `OPENAI_BASE_URL` filled
in for the gateway; to use plain OpenAI instead, delete that line and set a
real OpenAI model id (e.g. `gpt-4o`). Swap the model, keep the method. Run
`python -m lucid.check` to confirm your key, base URL, and model all resolve.

## Run it

Run these from the repo root, so `lucid` resolves as a package:

```bash
python -m lucid.run                    # Module 1: one agent, one pass over the bundled SecondSwap
python -m lucid.run path/to/contracts  # same, on a directory you choose
python -m lucid.run --context          # Module 2: protocol context + one context-aware pass
python -m lucid.run --loop             # Module 2: context + 5-round exclusion loop (--loop 3 for fewer)
python -m lucid.run --specialists      # Module 3: 5 specialists + hunter, 10 rounds each, + judge (--specialists 5 = 5 rounds per lane)
```

Every run makes real, paid API calls. Measured on the bundled target: a single
pass costs a few cents, `--loop` about $0.13, and `--specialists` about $1.30
and ~35 minutes (each specialist prints a line per round).
