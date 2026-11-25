# Brief for every agent working on this game

Read this first, then `docs/00-concept.md` (the user's pitch).

## This is NOT Dragon Tycoon
Your agent instructions may contain a "Dragon Tycoon" context section. It doesn't apply here. This game is a **blocky, multiplayer dinosaur survival game**: players spawn as a hatchling dinosaur, survive (hunger, thirst, stamina, injuries), grow into an adult, fight or flee, form herds and packs, and nest.

## Originality (hard rule)
- Genre mechanics (growth stages, hunger and thirst, herds, nests, carcasses) are fine to use.
- Do **not** copy names, models, art, UI layouts, maps, sounds, branding or species designs from *The Isle*, *Jurassic Blocky* or any other existing game. Every species gets an original blocky design. Real dinosaur genus names (Tyrannosaurus, Spinosaurus, Velociraptor, ...) are fine, because no game owns them.
- The working title "isle-roblox" is only the repo name. The game needs its own original title (propose some if your area touches it).

## Platform facts
- Roblox; plays on PC and mobile (touch controls matter), and console if cheap.
- Code is Luau, `--!strict`, synced with Rojo from `src/`:
  - `src/shared` → ReplicatedStorage.Shared (shared config and data; visible to clients)
  - `src/server` → ServerScriptService.Server (bootstrap only)
  - `src/modules` → ServerStorage.Modules (server services)
  - `src/client` → StarterPlayerScripts.Client, with `Controllers/` for client controllers
  - `src/tests` → ServerStorage.Tests
  - Services and controllers expose `Init()` / `Start()`. `src/shared/Loader.luau` runs them.
- World content (terrain, models, lighting, UI art) is built in Studio, in the place file. Claude can drive Studio directly through the Roblox_Studio MCP tools, including creating Parts by script and AI mesh, texture and material generation.
- Server-authoritative: health, damage, needs, growth, currency and inventory are decided on the server only.
- Roblox policy: show odds for paid random items, use PolicyService for restricted players, follow Roblox's monetization and age rules, and no pay-to-win stats.

## How to deliver
- Write **one markdown doc** at the path you're given in `docs/`. Keep it concise: tables over prose, numbers over adjectives.
- Separate the **MVP** (Prototype + Core loop phases) from **later**, and keep the MVP small enough to build first.
- End with **"Decisions for the user"**: a numbered list, each with options and your recommendation.
- Don't edit `src/`, don't change Studio, and don't git commit. Design only.
