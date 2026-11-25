# isle-roblox

A Roblox game, built with [Rojo](https://rojo.space). The code lives in this repo, and the world (terrain, parts, models) lives in the Roblox place.

## How the pieces fit

```
GitHub repo  <-- git push / pull -->  this folder (src/*.luau)  -- rojo serve -->  Roblox Studio
                                              ^                                         |
                                              |___ Claude edits files and drives Studio __|
```

- **Scripts** come from the files in `src/`. Edit them here, not in Studio. Rojo pushes every save into Studio live.
- **The world** (Workspace, Lighting, StarterGui, and so on) is built in Studio and saved to Roblox. Rojo never touches it.
- **CI** runs on pushes to `main` and on pull requests: StyLua format check, Selene lint, unit tests (Lune), and a Rojo build.

### Rojo rules that protect your work
- **Don't build things in Studio *inside* Rojo's folders** (`Shared`, `Server`, `Modules`, `Tests`, `Client`). Rojo owns those, and anything Studio-made in them is deleted on connect. Put RemoteEvents, models and so on *next to* them, or create them from code.
- **Don't create a Studio instance with one of those names yourself.** Rojo takes it over and replaces its contents.
- **On the first Connect, read the plugin's confirm dialog** before accepting.
- **Never publish a `rojo build` output** over the real place. It holds code only, no world.

## Daily workflow

1. Open the place in Roblox Studio.
2. Double-click **`sync.cmd`** and leave its window open.
3. In Studio: **Plugins > Rojo > Connect**.
4. Work. Edits to `src/` appear in Studio right away.
5. Double-click **`push.cmd`** to commit and push to GitHub.

## Layout

| Folder | Becomes in Studio | Runs on |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | server + client (visible to clients) |
| `src/server` | `ServerScriptService.Server` | server (bootstrap Script) |
| `src/modules` | `ServerStorage.Modules` | server-only modules |
| `src/tests` | `ServerStorage.Tests` | server-only tests |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | client (bootstrap + `Controllers`) |

`src/shared/Loader.luau` requires every ModuleScript that is a **direct child** of `src/modules` (server) or `src/client/Controllers` (client). Nested folders are skipped. Modules that return a table with `Init` and/or `Start` join the lifecycle: every `Init` runs in name order, then every `Start` runs in its own thread. Don't yield at the top level of a module, because that blocks every module loaded after it.

## Setup on a new PC

- Download `rojo-7.7.1-windows-x86_64.zip` from [Rojo's releases](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) and put `rojo.exe` in `.tools/` (gitignored). `sync.cmd` uses that path.
- Optional: [Rokit](https://github.com/rojo-rbx/rokit) + `rokit install` puts the pinned Rojo, StyLua, Selene and Lune from `rokit.toml` on your PATH (for running the CI checks locally; `lune run scripts/run-tests` runs the unit tests).
- Install the Studio plugin once: `.tools\rojo.exe plugin install`.
