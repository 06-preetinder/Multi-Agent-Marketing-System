# Marketing Multi-Agent System

A 3-agent marketing automation system — Lead Triage, Engagement, and Campaign
Optimization — with a polyglot memory architecture (short-term, long-term,
and episodic memory in SQLite; semantic knowledge graph in Neo4j) and a live
dashboard that makes agent activity and memory writes visible in real time.

**Live demo:** _add your Render URL here once deployed_

## What it does

Given a synthetic marketing dataset (leads, campaigns, interactions,
conversions), three agents make sequential decisions:

1. **Lead Triage** — categorizes an incoming lead (e.g. Campaign Qualified,
   General Inquiry) based on score, source, and any prior long-term
   preference or semantic signal already known about that lead.
2. **Engagement** — for a qualified lead, decides the next outreach action
   (email, SMS, call) and channel, informed by the lead's engagement history.
3. **Campaign Optimization** — evaluates a campaign's daily KPIs and decides
   whether to keep, adjust, or pause it.

Each agent action reads from and writes into memory as it runs — this is
the part of the system worth paying attention to.

## Memory architecture

| Tier | Store | Behavior |
|---|---|---|
| Short-term | SQLite | Per-interaction context, decays / gets superseded quickly |
| Long-term | SQLite | Durable preferences (e.g. a lead's preferred channel), persists |
| Episodic | SQLite | A capped log of "what happened" per lead/campaign, rolled up over time |
| Semantic | Neo4j (optional) | A knowledge graph of relationships — e.g. `Lead → engaged_via → Email` |

Every agent action is annotated with exactly which tiers it touched —
`engage_lead`, for example, typically writes to all four in a single call.
This is surfaced live in the dashboard's "Memory strata" band rather than
being invisible infrastructure.

## Architecture

```
app.py          Flask + Flask-SocketIO server, HTTP + JSON-RPC (MCP-style)
                endpoints, Socket.IO event emission
agents.py       The 3 agents, memory read/write/consolidate functions,
                Neo4j + Redis integration (both optional, degrade gracefully)
ingest.py       Loads the CSV dataset into the SQLite interactions table
client.py       A small JSON-RPC client for calling agents programmatically
openapi.yaml    API spec for the HTTP endpoints
static/
  events.html   Live dashboard — agent controls, event feed, memory strata
```

**Protocol layer:** in addition to plain REST endpoints
(`/api/demo/triage`, `/api/demo/engage`, `/api/demo/optimize`), the system
exposes a JSON-RPC 2.0 endpoint at `/mcp` for programmatic/agent-to-agent
calls, matching the MCP (Model Context Protocol) transport pattern.

## Running it

No API keys or `.env` file are required to run this — the agents are
rule-based, not LLM-backed, and Neo4j/Redis are both optional infrastructure
that the app detects and gracefully disables if unavailable.

```
pip install -r requirements.txt
python app.py
```

Then open `http://localhost:5000/events` for the dashboard.

**Optional — enable the semantic memory tier:**
Set `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD` (e.g. from a free
[Neo4j Aura](https://neo4j.com/cloud/aura-free/) instance) to have the
semantic tier populate with real graph edges instead of showing 0.

**Optional — enable Redis caching:**
Set `REDIS_URL`. Without it, the app falls back to an in-memory cache
automatically.

## Deployment

Deployed via Docker (see `Dockerfile`). Two things worth knowing if you're
redeploying this yourself:

- **Python version compatibility:** `jsonrpcserver==3.5.6` imports
  `Mapping`/`Sequence` directly from `collections`, which Python 3.10+
  removed (moved to `collections.abc`). The Dockerfile patches this at
  build time rather than pinning to an old Python image.
- **SQLite persistence:** on Render's free tier, the filesystem is not
  persistent across restarts/redeploys — `agent_memory.db` resets to empty
  each time the service restarts. Fine for a live demo, not for retaining
  history between sessions without a persistent disk or hosted DB.

No environment variables are required for deployment either — same
optional Neo4j/Redis variables as above if you want those tiers active.

## Known limitations

- No authentication on the API — fine for a demo, not for production data.
- Agents are rule-based (threshold/heuristic logic on the dataset), not
  LLM-driven — there's no language model in this system's decision loop.
- Debug mode is off by default (`FLASK_DEBUG=true` to enable locally) —
  Werkzeug's debugger allows code execution via the error page if left on
  in a public deployment, so this should stay off outside local dev.
