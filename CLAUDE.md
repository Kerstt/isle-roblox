# isle-roblox: notes for Claude

## Always use the Roblox agents
Every task and revision in this project goes through the specialist subagents in `~/.claude/agents`. This is the user's standing rule:
- `game-designer`: mechanic specs before code
- `roblox-systems-scripter`: Luau code, DataStores, remotes, security, Studio work
- `game-economy-designer`: currencies, prices, progression curves
- `roblox-experience-designer`: core loop, onboarding, monetization (within Roblox policy)
- `game-level-designer`: maps, spaces, blockouts
- `game-technical-artist`: art style, meshes, VFX, lighting, performance
- `roblox-avatar-creator`: avatar cosmetics and UGC
- `code-reviewer` before committing, `qa-tester` after building

Those agent files have Dragon Tycoon context baked in. This is a different game (**Brickjaw Island**, a blocky dinosaur survival game), so always point agents at `docs/AGENT_BRIEF.md` first. `docs/PLAN.md` is the approved master plan and wins over the detail docs (`docs/01`–`06`). The MVP tickets T01–T14 are in PLAN.md §5.

## Workflow
- Code lives as files in `src/` and syncs into Studio with Rojo (`sync.cmd`, which runs `.tools/rojo.exe serve default.project.json`). Don't edit scripts directly in Studio: Rojo would overwrite the change.
- Rojo maps folders *into* services with `$ignoreUnknownInstances`, so Studio-built content next to those folders is safe. Workspace, Lighting and StarterGui belong to the place file. Build world content in Studio through the Roblox_Studio MCP tools, then save the place to Roblox.
- Inside the mapped folders (`Shared`, `Server`, `Modules`, `Tests`, `Client`) the files are the only truth: anything created there in Studio gets deleted on sync. Create RemoteEvents and similar instances from code, or next to those folders. Never publish `rojo build` output over the place.
- Before committing: `.tools/rojo.exe build default.project.json -o build.rbxl` must succeed. CI also runs `stylua --check src` and `selene src` (see `stylua.toml` and `selene.toml`).
- Every `.luau` file starts with `--!strict`. Server modules and client controllers expose `Init`/`Start` for `src/shared/Loader.luau`.
- Repo: https://github.com/Kerstt/isle-roblox (public). Don't commit secrets, API keys or place files.
