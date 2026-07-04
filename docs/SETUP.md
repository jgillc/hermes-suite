# Hermes Suite — Setup & Best Practices

## Current Setup

| Component | Detail |
|-----------|--------|
| **Install** | Local (containerless) via `hermes_local/install.sh` |
| **Agent** | NousResearch/hermes-agent v2026.6.19 |
| **WebUI** | nesquena/hermes-webui v0.51.742 |
| **Config** | Free tier (`config-free.yaml`) — model `big-pickle` via OpenCode Zen |
| **API Keys** | OpenRouter, HF Token, Telegram, Exa, Firecrawl |
| **Runtime** | Local terminal backend |
| **Gateway** | Running with Telegram connected |
| **Auth** | `GATEWAY_ALLOW_ALL_USERS=false` — Telegram allowlist only |
| **Dev tools** | shellcheck, yamllint, ruff, pre-commit |
| **Tests** | `make test` (syntax), `./hermes_local/test.sh` (integration, 19 tests) |
| **Services** | Port 8787 (WebUI), 9119 (Dashboard), 8642 (Gateway) |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Host Machine                       │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ Gateway  │  │ Dashboard│  │     WebUI         │   │
│  │ :8642    │  │ :9119    │  │ :8787             │   │
│  │ Telegram │  │ Monitor  │  │ Chat Interface    │   │
│  │ Platform │  │ Config   │  │ API Routes        │   │
│  └────┬─────┘  └──────────┘  └──────────────────┘   │
│       │                                              │
│  ┌────▼─────────────────────────────────────────┐    │
│  │          Hermes Agent (Python CLI)            │    │
│  │  ~/.hermes/config.yaml                       │    │
│  │  ~/.hermes/.env (API keys)                   │    │
│  │  ~/.hermes/memories/{MEMORY,USER}.md         │    │
│  │  ~/.hermes/skills/  ~/.hermes/sessions/      │    │
│  │  ~/.hermes/logs/                             │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │          Dev Toolchain                        │    │
│  │  shellcheck │ yamllint │ ruff │ pre-commit    │    │
│  │  Makefile: lint │ test │ security │ all       │    │
│  └──────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

## Official Best Practices

### Configuration

- **Secrets in `.env`, everything else in `config.yaml`** — API keys, tokens, passwords go in `.env`; model, terminal backend, toolsets go in `config.yaml`
- **Use `hermes config set`** to let the tool route values to the right file automatically
- **Environment variable substitution** — reference env vars in config: `${VAR_NAME}`
- **Never commit `.env`** — it's in `.gitignore` already

### Security

- **Always set allowlists** — never use `GATEWAY_ALLOW_ALL_USERS=true` in production. Use per-platform allowlists (`TELEGRAM_ALLOWED_USERS`, etc.)
- **Enable DM pairing** instead of hardcoding user IDs: `hermes pairing approve <platform> <code>`
- **Use Docker terminal backend** for production: `terminal.backend: docker` sandboxes commands
- **Set `approvals.mode: manual`** — keeps dangerous command approval on by default
- **Run `hermes doctor` periodically** — checks for security advisories and config issues
- **Secure `.env` permissions**: `chmod 600 ~/.hermes/.env`
- **Keep supply-chain advisories checked**: `hermes doctor` flags known-compromised packages

### Memory

- **Two-file system**: `MEMORY.md` (agent notes, 2200 chars) + `USER.md` (user profile, 1375 chars)
- **Keep entries compact** — merge related facts, remove stale ones
- **Memory is a snapshot at session start** — changes persist to disk but won't appear until next session
- **Use `write_approval: true`** to gate agent memory writes
- **Session search** (`session_search` tool) supplements memory for recall without token cost
- **Provider comparison** from community: built-in markdown system is preferred by many over external providers

### Terminal Backends

| Backend | Isolation | Use Case |
|---------|-----------|----------|
| **local** | None | Development, trusted tasks |
| **docker** | Container | Production, sandboxing |
| **ssh** | Remote host | Keep agent away from its own code |
| **modal** | Cloud sandbox | Serverless, scale |

## Community Wisdom (Reddit)

### From "Three months with Hermes Agent" (530 upvotes)

- **Memory ≠ remembering** — "Agents don't remember. Agents read." The built-in markdown memory files (MEMORY.md / USER.md) are the most reliable system
- **Profile count matters** — Keep ≤4 profiles. Each should be a distinct "colleague" with its own voice and stack. Having more means you're over-splitting
- **Terminal gets quiet** — After using Hermes for a while, you stop typing raw commands. Work shifts from execution to description
- **Runs on $50 hardware** — Raspberry Pi 4 with 8GB RAM is sufficient
- **No vendor lock-in** — Fully free and open source, you control where your money goes

### From "How I use Obsidian as long-term memory" (1038 upvotes)

- **Three-tier memory**: Hot (session, ~9K chars) → Vault (stable reference) → Daily Notes (searchable timeline)
- **Morning briefing pipeline**: Cron fetches calendar + tasks + email → formats daily note → delivers to Telegram
- **Plain text markdown**: AI reads and writes without plugins
- **Obsidian's graph view** shows connections over time naturally through wiki-links
- **Always append to daily notes**, never delete — creates a true decision history

### From "Memory Providers: I tested them all" (292 upvotes)

- **Mnemosyne** recommended as best balanced memory provider: SQLite + fast embeddings + tiny local LLM
- **Hindsight** most capable but heavy on API calls and complex to configure
- **OpenViking** hard to set up
- **Holographic** fast but quality wasn't there
- **Honcho** good profiling but same complexity issues as Hindsight
- Consensus: start with built-in markdown files, add a provider only when you hit specific limits

### From "BEST FREE MODEL for Hermes" (423 upvotes)

- **Ring 2.6** (free on OpenRouter) is the current best free model — excellent tool-calling
- Burns through tokens (thinks a lot), but quality justifies it
- OpenRouter's `:free` models provide 95% of functionality for most use cases

## Production Deployment Checklist

- [ ] **Set explicit allowlists** — no `GATEWAY_ALLOW_ALL_USERS=true`
- [ ] **Use Docker terminal backend** — `terminal.backend: docker`
- [ ] **Restrict resource limits** — CPU, memory, disk caps
- [ ] **Store secrets securely** — `.env` with `chmod 600`
- [ ] **Enable DM pairing** — `unauthorized_dm_behavior: pair`
- [ ] **Review command allowlist** — audit `command_allowlist` in config.yaml
- [ ] **Run as non-root** — never run gateway as root
- [ ] **Monitor logs** — check `~/.hermes/logs/` for unauthorized access
- [ ] **Keep updated** — `hermes update` regularly
- [ ] **Use SSH backend** for host/agent isolation — agent can't modify its own code

## Future Improvements

### Short-term

1. **Set up cron jobs** — morning briefings, scheduled tasks, daily summaries
   ```
   hermes cron create --schedule "0 7 * * 1-5" --prompt "prepare morning briefing"
   ```
2. **Add a personality** — create `~/.hermes/SOUL.md` with identity and behavior rules
3. **Create skills** — save recurring workflows as reusable skills
   ```
   hermes skills create --from "recent session"
   ```
4. **Enable background review** — let the agent learn from past sessions
   ```
   auxiliary:
     background_review:
       provider: openrouter
       model: google/gemini-3-flash-preview
   ```

### Medium-term

5. **Switch to Docker terminal backend** for command sandboxing
6. **Set up SSH backend** on a separate machine for production isolation
7. **Explore Mnemosyne** for deeper memory if built-in limits become constraining
8. **Add more profiles** (code, research, personal) once you understand the split
9. **Integrate Obsidian vault** as persistent knowledge base (see community template)
10. **Enable `write_approval: true`** for memory and skills once agent patterns stabilize

### Long-term

11. **Deploy on dedicated hardware** — Raspberry Pi 5 or low-power server
12. **Multi-agent orchestration** — use kanban/delegation for parallel workstreams
13. **Custom skills from workflows** — capture repeated patterns as formal skills
14. **MCP server integration** — connect to external data sources via Model Context Protocol
15. **Monitoring dashboard** — track token usage, session patterns, cost analytics
16. **Automated backups** — cron job for `~/.hermes/` backups

## References

- [Official Docs](https://hermes-agent.nousresearch.com/docs/)
- [GitHub](https://github.com/NousResearch/hermes-agent)
- [Configuration Guide](https://hermes-agent.nousresearch.com/docs/user-guide/configuration)
- [Security Guide](https://hermes-agent.nousresearch.com/docs/user-guide/security)
- [Memory Guide](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory)
- [Tools Guide](https://hermes-agent.nousresearch.com/docs/user-guide/features/tools)
- [Reddit r/hermesagent](https://reddit.com/r/hermesagent)
- [Discord](https://discord.gg/NousResearch)
