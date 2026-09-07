# Routing Guide — Local Qwen vs Perplexity Computer

Decision framework for when to stay local (free) and when to escalate to Perplexity Computer (credits).

## Default: Always Try Local First

Your local harness pointed at Qwen (via vLLM or LM Studio) handles the vast majority of dev work at zero external cost. Start here every time.

**Local Qwen is good at:**
- Everyday coding: refactoring, bug fixes, writing tests
- Reading and applying skills from `shared/skills/`
- Multi-file edits within a well-bounded task
- Running MCP tools (git, docker, redis, etc.)
- Docs, comments, commit messages
- Standard financial math (Sharpe, VaR, position sizing)
- Q&A on code you already have

## Escalate to Perplexity Computer When...

**1. You need a Perplexity-only connector.** These do not exist locally:
- `finance` — real-time market data, earnings, filings, ratios
- `opticodds` — sports odds data
- Any other Perplexity native connector (GitHub, Linear, Notion, Slack, etc.) unless you've wired their MCP equivalent locally

**2. You need deep research across many sources.** Perplexity Computer runs parallel browser tasks and web searches with much stronger synthesis than a local model can manage.

**3. Local Qwen has failed twice on the same problem.** Two honest tries with different phrasings. If still stuck, one Perplexity session is cheaper than an hour of local thrashing.

**4. The task requires holding 50+ files in context.** Frontier models on Perplexity have much larger practical context windows than Qwen 32B under vLLM.

**5. The output has real financial or legal stakes.** Position sizing for actual capital, contract interpretation, compliance reviews — anywhere hallucination cost is high, verify with Perplexity Computer even if Qwen produced an answer.

**6. Novel algorithm or system design from scratch.** Local Qwen handles well-known patterns; Perplexity Computer is stronger at synthesizing genuinely new approaches.

## Do NOT Escalate For...

- Casual chat or "what does this code do"
- Simple grep / search / find operations
- Editing docs or config files
- Anything you'd have done in Claude Code without thinking
- Running an existing MCP tool
- Formatting, linting, type-fixing

## The Two-Try Rule

If Qwen fails once, rephrase and try again with more context. If it fails twice, escalate. This prevents both premature escalation (wasting credits) and endless local looping (wasting your time).

## Batching Perplexity Sessions

When you do escalate, batch questions. One well-formed session with three related questions is cheaper than three sessions each rediscovering context. Load all the context up front — paste error logs, relevant code, what you already tried — then let Perplexity Computer work through them.

## Credit-Zero Verification

If you want to confirm a session is truly local:
- Your terminal shows the local harness (Continue.dev, Cline, Aider, etc.)
- The model badge shows Qwen or your local model name
- No Perplexity tab is open

The moment you open perplexity.ai and start a chat, you're on credits. Nothing about local skills or MCPs changes that — it's about which service processes the prompt.
