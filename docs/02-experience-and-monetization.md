# 02 - Player experience and monetization

Owner: roblox-experience-designer. Status: draft for review, 2026-11-26.
Reads with: `00-concept.md`. Game design and economy docs (species stats, growth times, coin values) override any placeholder number here once they exist; every number below marked *(tune)* is a starting point for `game-economy-designer`.

Ground rules this doc follows:
- **Robux never buys combat power, growth or survival.** It buys looks, convenience that does not win fights, and access to private servers.
- **No paid random items at launch.** Everything sold has a fixed, visible result.
- **One earned currency (Fossil Coins) plus direct Robux prices.** No second premium currency.
- Server decides every grant, price check and unlock. The client only asks.

---

## 1. First-time user experience (join to first meaningful moment in under 2 minutes)

### 1.1 Timeline

Target: a new player drinks, eats, grows a little and survives (or escapes) a threat before the 2:00 mark. No forced tutorial, no text walls, no cutscene.

| Time | Moment | What the player does | What the game does | Success signal |
|---|---|---|---|---|
| 0:00 | Join | Nothing | Short loading screen with title art and one tip. Data loads in the background. | Loading under 10 s on mobile |
| 0:05 | Species pick | Taps one of the owned species cards | 3 cards max on first join: free starter carnivore, free starter herbivore, plus one locked card showing what can be earned. One card is tagged "Good first pick". Tapping a card spins its hatchling in a ViewportFrame; one "Hatch" button. | Pick under 20 s |
| 0:20 | Spawn | Moves | Hatchling cracks out of an egg in a **Nursery** (a safe-ish starter area near water and food, one per biome edge). Thirst starts at 55%, hunger at 70%, so the first need is real but not urgent. Spawn shield 90 s (see 1.3). | Player moves within 5 s |
| 0:30 | First need | Follows the hint to water | Hint chip: "Thirsty. Find water." plus a soft pulse on the thirst bar and a faint ground trail to the nearest water (max 40 studs away). | Reaches water |
| 0:45 | First drink | Holds the contextual Drink button | Bar fills with a satisfying sound. "+10 Fossil Coins, first drink" toast. Growth bar appears for the first time at 1%. | Drink completes |
| 1:00 | First eat | Herbivore: eats a glowing fern patch. Carnivore: chases a slow NPC prey critter (one bite kills it). | Hint: "Hungry. Ferns glow where food is." or "Catch the small lizard." Food is placed within 30 studs of the water. | Eats once |
| 1:20 | Growth tick | Sees growth jump | Growth bar animates 1% to 4%. Text: "Eat, drink and survive to grow into an adult." Stage icons (hatchling to adult) shown once. | Player looks at growth bar (no input required) |
| 1:30 | First threat | Runs or hides | A scripted NPC predator (the "Stalker", AI, not a player) appears at the Nursery edge and roars. Hint: "Danger! Hold Sprint or hide in tall grass." The Stalker gives up when the hatchling sprints 25 studs away or enters tall grass. It can hit once for 20% health but cannot kill a hatchling on its first life. | Escapes |
| 1:50 | Payoff | Feels safe | "You survived your first threat. +25 Fossil Coins." Survival Journal opens as a small panel (see 1.2), then auto-collapses to a corner icon after 5 s. | First session goal visible |

Fallbacks: if a step is not done within 45 s, the hint escalates once (arrow plus a short sound), never more. If the player ignores everything, the game still works; the hints just wait.

### 1.2 Tutorial approach: light hints plus a Survival Journal

| Element | Rule |
|---|---|
| Hint chips | One at a time, top-centre, max 6 words plus an icon. Triggered by state (low thirst, near carcass, stamina empty, first night), not by a script order. Each hint fires at most 3 times per account, then retires. |
| Survival Journal | An optional checklist of the first 8 goals, each with a small coin reward: drink, eat, escape a threat, rest to heal, reach Juvenile, join or make a herd, survive a night, find a nest site. Rewards are paid once per account. |
| Contextual buttons | Drink, Eat, Rest, Lay Egg appear only when possible. This teaches by showing what can be done right here. |
| Death as teacher | Death screen shows the cause in plain words ("Starved", "Killed by an adult Tyrannosaurus", "Bled out") and one tip for that cause, then the Respawn button. No "revive for Robux" button (see 4.6). |
| Settings | "Hints: On / Off". Returning players with 3+ sessions get hints off by default. |
| Not doing | Forced tutorial island, locked controls, long dialogue, a mentor NPC that talks. Survival games lose people when the tutorial feels like a separate game. |

### 1.3 New-player protection (core to the first 2 minutes)

| Rule | Value *(tune)* | Why |
|---|---|---|
| Spawn shield | 90 s, or until the player attacks, whichever first. Shown as a soft shell glow. | Prevents spawn camping, the number one early quit reason in PvP survival games |
| Nursery zones | Players at Sub-adult or Adult take 50% more damage and deal 0 damage to hatchlings inside a Nursery | Keeps the learning space safe without making it a full safe zone |
| First-life Stalker | Scripted NPC threat cannot kill on the account's first life | The first threat must be a thrill, not a loss |
| Hatchling kill value | Killing a hatchling gives no coins and no leaderboard credit | Removes the reward for griefing new players |

### 1.4 Mobile control layout

Design for a 6-inch phone in landscape first, then scale up. Use `GuiObject` buttons placed inside the device safe area (`ScreenGui.ScreenInsets = DeviceSafeInsets`), not the default jump button position. Minimum touch target 56 x 56 px; primary attack 88 x 88 px.

```
+-------------------------------------------------------------+
| [Hunger][Thirst][Stamina]          [Growth %]    [Map][Herd]|
| [Health]                           (hint chip)        [Shop]|
|                                                             |
|                                                    [Special]|
|                                            [Roar]           |
|                                                      [BITE] |
|  ( thumbstick )                      [Sprint]   [Interact]  |
|                                               [Jump]        |
+-------------------------------------------------------------+
```

| Control | Mobile | PC | Console | Notes |
|---|---|---|---|---|
| Move | Dynamic thumbstick, left half | WASD | Left stick | |
| Camera | Drag right half | Mouse (right-drag or shift-lock) | Right stick | |
| Bite (primary) | Biggest button, bottom right | Left click | R2 | |
| Species special | Above Bite, shows cooldown ring | E | R1 | |
| Sprint | Toggle, not hold (holding plus aiming is hard on glass) | Left Shift (hold) | L3 | Stamina ring around the button |
| Interact (Drink/Eat/Rest/Lay Egg) | Contextual, appears only when valid, icon changes | F | X / Square | Hold-to-use with a fill ring |
| Roar / call | Small button | Q | Y / Triangle | Herd ping on long-press |
| Jump | Small, bottom right | Space | A / Cross | |
| Map, Herd, Shop | Top-right icons | M, H, B | Menu | Shop icon hidden during combat (10 s after last hit) |

Rules: no button overlaps the thumbstick zone; no more than 6 action buttons on screen at once; HUD bars use icons plus colour plus fill, readable without colour vision.

---

## 2. Retention

### 2.1 What brings a player back

| Horizon | Hook | MVP or later |
|---|---|---|
| Next session (same day) | **Saved dino slots**: the dino you grew stays grown when you leave (saved per slot; death resets that slot to a hatchling). "Your Juvenile Raptor is waiting" is the strongest reason to return. | MVP |
| Tomorrow | Daily Forage reward (2.2) and 3 new Daily Instincts (2.3) | MVP: Daily Forage. Instincts: later (week 6+) |
| This week | Weekly shop rotation (3.4), weekly leaderboard reset, weekly server event (meteor shower or volcano day) | Later |
| This month | New species or biome update, Species Mastery tiers, monthly cosmetic set | Later |
| Long term | Fossil Record (collection of every species grown to adult, per account), achievement badges, seasonal track | Later |

### 2.2 Daily Forage (login reward)

A 7-step calendar that advances **on each day you log in**, not on consecutive days. Missing a day pauses progress; it never resets it. This keeps the return habit without punishing a kid who missed a day.

| Day | Reward *(tune)* |
|---|---|
| 1 | 50 Fossil Coins |
| 2 | 75 Fossil Coins |
| 3 | Common effect (footstep dust colour) |
| 4 | 100 Fossil Coins |
| 5 | 150 Fossil Coins |
| 6 | 200 Fossil Coins |
| 7 | Calendar-exclusive skin (a new one each cycle, earnable only, never sold) |

Claimed by a button on join (not auto-granted, the tap is the satisfying moment). Day boundary is UTC midnight, server time. VIP adds +25% coins to coin days, not extra steps.

### 2.3 Session goals (Daily Instincts, later)

3 per day, drawn from a pool, each 5 to 15 minutes of normal play. Examples: "Drink 5 times", "Survive a full night", "Grow 10%", "Eat from a carcass", "Travel to the swamp", "Rest with a herd mate". None require killing players. Reward: coins *(tune)*, plus a weekly bonus for completing 15 in a week. One free reroll per day.

### 2.4 Leaderboards

| Board | Scope | Reset | Notes |
|---|---|---|---|
| Longest life (current) | Server, live | On death | Shown in `leaderstats` next to growth stage. Most readable status in the server. |
| Longest life | Global | Weekly | `OrderedDataStore` keyed by ISO week |
| Adults raised | Global | All-time | Counts each time a dino reaches Adult |
| Apex hunter | Global | Weekly | Counts kills only of dinos at your growth stage or above. Hatchling and juvenile kills by bigger dinos score 0. |
| Biggest herd survival | Global | Weekly (later) | Total herd life time |

Physical leaderboard boards at Nurseries (in-world `SurfaceGui`) plus a tab in the menu. Show top 50 plus the player's own rank.

### 2.5 Social hooks

| Feature | Design | MVP or later |
|---|---|---|
| Herds and packs | Create or invite; cap 6 (herbivores) / 4 (carnivores) *(tune with game-designer)*. Herd mates see each other on the map and compass. Small bonus: +10% health regen when within 30 studs of a herd mate. | MVP (basic group plus map markers). Bonus: later |
| Herd chat | A private `TextChannel` per herd via TextChatService (see 7.1) | MVP |
| Map pings | Fixed icons only (Danger, Food, Water, Come here, Nest). No free text. | MVP |
| Herd nest spawn | A herd member who dies can respawn as a hatchling at the herd's nest | Later (with nests) |
| Invite friends | "Invite" button in the Herd menu calls `SocialService:PromptGameInvite` with launch data that drops the friend into your server and auto-offers herd membership | MVP |
| Friend bonus | When a friend joins via your invite and plays 10 minutes, both get a "Herd Bond" cosmetic (one per account, not repeatable, no coins). Cosmetic-only removes the incentive to farm alt accounts. | Later |
| Join a friend | Friends list in the menu with "Join" where the friend's server has room | Later |
| Favorite prompt | Shown once, at the first time the player reaches Juvenile (a natural high point), never during combat | MVP |
| Photo mode | Free camera plus emotes; good for social sharing | Later |

---

## 3. Shop UX

### 3.1 Layout

One `ScreenGui`, opened by the Shop icon or at Nursery shop totems. Closed automatically on taking damage.

| Area | Content |
|---|---|
| Left rail (tabs) | Featured, Skins, Accessories, Effects, Emotes, Species, Passes. Mobile: tabs become a top scroll strip. |
| Centre (grid) | Item cards: icon, name, price chip, state badge. 4 columns on PC, 2 on phone. |
| Right (preview) | ViewportFrame of **your currently selected species** wearing the selected item. Drag to rotate, pinch or scroll to zoom, a growth-stage switcher (Hatchling / Adult) so a buyer sees what the skin looks like at both sizes. Effects play a looped sample. |
| Footer | Fossil Coin balance and a "How to earn coins" link. No Robux balance display (Roblox shows that in the prompt). |

Item cards say which currency they use. Robux items carry a Robux icon; coin items a fossil icon. Paid and earned items are never mixed under one ambiguous "price" label. Robux prices are read live from `MarketplaceService:GetProductInfo` so regional prices show correctly.

### 3.2 Item states

| State | Card badge | Button | Behaviour |
|---|---|---|---|
| Equipped | Check mark | "Unequip" | |
| Owned | None | "Equip" | Equipping is instant, no confirm |
| Buy with coins | Coin price | "Buy" | Confirm sheet: item, price, balance after. Server re-checks balance and ownership. |
| Not enough coins | Coin price greyed | "Need 120 more" | Tapping shows ways to earn, never a coin-pack upsell for kids as the first option |
| Buy with Robux | Robux price | "Buy" | Opens Roblox's native purchase prompt. Item granted only after `ProcessReceipt` saves. |
| Locked (requirement) | Padlock plus reason | Disabled | E.g. "Reach Adult as Triceratops", "Day 7 Daily Forage", "Mastery tier 2" |
| Species not owned | Species silhouette | "Preview" only | Cosmetics are per species; shows which species it fits |
| Not in rotation | "Returns later" | Disabled | For past Featured items; visible in a "Vault" filter so nothing feels lost forever |
| Restricted by policy | Hidden | n/a | Items hidden for players whose policy restricts them (only relevant if random items ever ship) |

### 3.3 Equip model

Cosmetics are owned per account, equipped per species (one skin, up to 2 accessories, 1 effect, emote wheel of 4). Equips save with the slot. The preview always reflects the loadout that will be used on the next spawn.

### 3.4 Rotating Featured shop

| Rule | Value |
|---|---|
| Rotation | Weekly, Monday 00:00 UTC. 6 Featured slots: 4 cosmetics for coins, 2 for Robux *(tune)*. |
| Countdown | A calm "Rotates Monday" label. No ticking seconds, no flashing, no "last chance" pop-ups. |
| Returns | Every Featured item returns in a later rotation (no artificial permanent scarcity). Founders and event items are the only exceptions and say so on the card. |
| Seeding | Rotation is a fixed schedule table in `src/shared` (deterministic per week), so every server shows the same shop and support can answer "what was in the shop on date X". |

---

## 4. Monetization plan (Roblox-compliant, late 2026)

### 4.1 Platform model: what is true now, and what to verify

| Topic | My understanding | Confidence | Action |
|---|---|---|---|
| Premium Payouts | Roblox replaced Premium Payouts with **Creator Rewards** in mid-2025. Creators are rewarded for engagement from users who spend on Roblox (daily engaged users) and for bringing in new or returning users (audience expansion). It is no longer tied only to Premium members' play time. | Medium-high | Check the Creator Rewards page and Creator Dashboard before launch. The concept's "Premium Payouts" line is likely outdated. |
| Premium perks | Still allowed and worth doing: Premium members are spenders, so they count towards rewards. Detect with `Player.MembershipType`, listen to `Players.PlayerMembershipChanged`, upsell with `MarketplaceService:PromptPremiumPurchase`. | High | Keep perks small (4.4) |
| Game Passes / Developer Products | One-time / repeatable. Pass ownership via `UserOwnsGamePassAsync`; products need an idempotent `ProcessReceipt`. | High | |
| Regional pricing | Roblox added opt-in regional pricing for passes and products (2025). | Medium | Enable it, and always read displayed prices from `GetProductInfo`, never hard-code Robux numbers in UI. |
| Price optimization | A Creator Dashboard tool that tests price points automatically. | Medium | Use after launch, once traffic exists |
| Experience Subscriptions | Monthly recurring products, priced in local currency. | Medium-high | Later: candidate for a "Herd Leader" monthly supporter subscription instead of more passes |
| Rewarded video ads | Available for some audiences (13+ and some regions), opt-in, gated by `PolicyService` `AreAdsAllowed`. | Medium | Later, optional; never forced, never for growth or revive |
| Paid random items | Must show all outcomes and odds before purchase; respect `ArePaidRandomItemsRestricted`. Rules have been tightening. | High (rule), Medium (current detail) | Avoid at launch (4.5) |
| DevEx rate | Raised in 2025 (around $0.0038 per Robux). | Medium | Not a design input; noted for revenue estimates only |

### 4.2 Pay-to-win review of the concept's items

This is a PvP survival game. A paid advantage in a fight, in growth, or in surviving death means paying players kill free players, free players quit, servers empty, and the paying players leave too.

| Concept item | Risk | Verdict | Replacement |
|---|---|---|---|
| **Instant growth** (product) | Severe. A bought adult kills earned hatchlings. Growth is the whole progression. | **Drop** | Nothing paid touches growth. Free growth helpers instead: resting in a herd, eating a "big meal" carcass, the Daily Instinct "Grow 10%". |
| **Growth boost / XP boost** (shop boost) | High. Same problem, slower. | **Drop** | Same as above |
| **Revive** (product) | Severe. Death is the stake that makes every fight and every escape matter. Buying back a life undoes the killer's win. | **Drop** | Free respawn as a hatchling (at Nursery or herd nest). Saved slots soften the loss: other slots keep their growth. |
| **Nest respawn** (product) | Medium. Respawning at a herd's nest is a positioning advantage. | **Drop as paid; keep as free mechanic** | Herd nest respawn is free for every herd member |
| **Extra nest slot** (boost) | Medium. More hatchlings for your herd means more bodies in fights. | **Drop as paid** | Nest capacity set by game design, equal for all |
| **2x Coins** (pass) | Low, **if** coins only buy cosmetics and balanced species. | **Keep**, with the condition below | Rename "2x Fossil Coins". Applies to gameplay earnings only, not to Daily Forage or Journal rewards. |
| **Extra dino slots** (pass) | Low. A payer keeps more grown dinos in storage, but each one still had to be grown, and only one plays at a time. | **Keep** | Free: 3 slots. Pass: +3. Death still resets the slot that died. Slot switching only in a Nursery, 60 s cooldown *(tune)*, so it cannot be used to escape a fight. |
| **VIP** (pass: daily coins, chat tag) | Low | **Keep** | Perks in 4.3. No combat, growth, or survival perk. |
| **Exclusive Skin Pack** (pass) | None | **Keep** | |
| **Coin packs** (product) | Low to medium. Fine while coins buy only cosmetics and species sidegrades. Becomes pay-to-win the moment coins buy anything that helps in a fight. | **Keep, later** (after the economy is tuned) | Hard rule for economy design: nothing that changes combat, growth or survival is ever priced in coins. |
| **Premium species** (Spinosaurus-style, mythic crystal dino) | High if Robux-only and stronger. | **Change** | Every species is earnable with coins and balanced as a sidegrade. Robux may buy a species unlock directly only if it is also earnable in under ~6 hours of play *(tune)*. The "crystal dino" becomes a premium **skin** set across species, not a stronger species. |
| **Mutations** (random trait on hatch) | High if paid rerolls exist (paid random item plus power). | **Keep free, never sell rerolls** | Mutations stay small, random, free, and if they affect stats at all they are side-grades |
| **Battle pass premium track** | Low if cosmetic | **Later**, cosmetic and coin rewards only | |

### 4.3 Game Passes

| Pass | Perks | Price *(tune)* | Phase |
|---|---|---|---|
| VIP | Gold name tag in chat and above head, VIP cosmetic set (1 skin per launch species, 1 effect), +25% coins on Daily Forage coin days, VIP pose emote | 299 R$ | MVP-monetization |
| 2x Fossil Coins | Doubles coins earned from gameplay (survival time, growth stages, kills, Instincts) | 349 R$ | MVP-monetization |
| Extra Dino Slots | +3 saved dino slots (3 to 6) | 199 R$ | MVP-monetization |
| Founders Pack | Launch-only skin set plus a "Founder" title; sold for the first 30 days, card says so up front | 249 R$ | Launch |
| Emote Pack | 6 emotes (sit, sleep, dance, stomp, tail wag, sunbathe) | 149 R$ | Later |
| Season Track (per season) | Premium track of the season: cosmetics plus coins only | 399 R$ | Later |

### 4.4 Developer Products, Private Servers, Premium

**Developer Products**

| Product | Content | Price *(tune)* | Phase |
|---|---|---|---|
| Featured cosmetic (per item) | One fixed cosmetic from the rotating shop | 75 to 299 R$ by rarity | Launch |
| Cosmetic bundle | Skin plus accessory plus effect themed set, about 30% below separate prices | 399 to 599 R$ | Launch |
| Coin pack S / M / L | 1,000 / 2,750 / 6,000 Fossil Coins *(tune with economy)* | 99 / 249 / 499 R$ | Later (after economy tuning) |
| Species unlock (shortcut) | Unlocks one coin-priced species directly. Only for species also earnable in about 6 hours. | 149 to 249 R$ | Later |
| Name tag colour change | Cosmetic | 49 R$ | Later |

Implementation note for the systems scripter: one Developer Product per sellable cosmetic is the simplest idempotent model. If the count gets too large, use per-price-tier products with a server-side "pending purchase intent" record that `ProcessReceipt` resolves; the intent must be stored before the prompt opens.

**Private Servers**

| Item | Value |
|---|---|
| Price | 199 R$ per month *(tune; check what comparable survival games charge at launch)* |
| Owner tools | Time of day, weather, NPC density, PvP on/off, growth speed x1 to x3 |
| Progression rule | **Growth, coins, kills and leaderboards do not save from private servers** where the owner changed growth speed or PvP. They are a sandbox for friends, roleplay and practice. If settings are default, coins and growth save normally. |
| Phase | Later (after core loop and moderation basics) |

**Premium perks** (small, cosmetic or earnings only)

| Perk | Value |
|---|---|
| Coin bonus | +10% Fossil Coins from gameplay |
| Cosmetic | A Premium-only footstep effect |
| Upsell | One quiet "Premium benefits" line in the Passes tab; `PromptPremiumPurchase` only on tap. No pop-ups. |

### 4.5 Second currency and random items

**Premium currency: not needed. Recommend Fossil Coins plus direct Robux prices.**

| Option | Pros | Cons |
|---|---|---|
| A. Fossil Coins (earned) + direct Robux prices (recommended) | Kids see the real Robux price in Roblox's own prompt; no confusing conversion; simpler data and receipts; Roblox policy flags a second currency used for random items | Coin packs exist later, so coins are partly buyable; economy must keep coins cosmetic-only |
| B. Fossil Coins + a premium currency ("Amber") bought with Robux | Common in Roblox games; bundles and bonuses are easy | Obscures real cost for a young audience; extra code and audit surface; tempts into odd pack sizes that leave leftovers, a known dark pattern |

**Paid random items: avoid them entirely at launch.** Reasons: the audience is mostly 9 to 15; the rules keep tightening; restricted players would need a full alternative shop; and a fixed-price rotating shop gives the same "new stuff each week" pull without gambling.

If random items are ever added (later, a decision for the user):
- Show every outcome and its exact odds before purchase, from the same shared table the server rolls from.
- Call `PolicyService:GetPolicyInfoForPlayerAsync` on join. If `ArePaidRandomItemsRestricted` is true, or the call fails, hide random items and show direct-purchase versions. Fail closed.
- Cosmetic-only, with a duplicate-protection rule, and every roll logged for audit.
- Even with zero random items, still call `PolicyService` on join for `AreAdsAllowed`, `AllowedExternalLinkReferences` and `IsPaidItemTradingAllowed` (no trading in v1).

### 4.6 Ethics guardrails (apply to every product)

| Rule | Example |
|---|---|
| No purchase prompt opens without a player tap | No auto-popup on death, on join or on level up |
| No paid option on the death screen | Death screen shows cause, tip, Respawn. Nothing else. |
| No urgency theatre | No seconds countdowns, no "only 3 left", no "your friend bought this" |
| Clear labels | "Robux" or "Fossil Coins" on every price; "Earned" badge on items that cannot be bought |
| Free game is complete | Every species, biome, herd, nest and leaderboard is reachable for free |

---

## 5. Launch product list

| # | Product | Type | Price *(tune)* | Phase | Why |
|---|---|---|---|---|---|
| 1 | VIP | Game Pass | 299 R$ | MVP-monetization | Highest-converting pass type on Roblox; status, not power |
| 2 | 2x Fossil Coins | Game Pass | 349 R$ | MVP-monetization | Classic, safe while coins stay cosmetic |
| 3 | Extra Dino Slots | Game Pass | 199 R$ | MVP-monetization | Convenience tied to the core retention hook |
| 4 | Founders Pack | Game Pass | 249 R$ | Launch (30 days) | Rewards early players; honest time limit |
| 5 | Featured cosmetics (2 per week) | Dev Products | 75 to 299 R$ | Launch | Weekly reason to look at the shop |
| 6 | Cosmetic bundles (2 at launch) | Dev Products | 399 / 599 R$ | Launch | Higher-value option, anchors single prices |
| 7 | Private Servers | Private server | 199 R$/month | Later | Reliable earner in survival games; needs settings and save rules |
| 8 | Coin packs S/M/L | Dev Products | 99 / 249 / 499 R$ | Later | Only after coin economy is simulated |
| 9 | Species unlock shortcuts | Dev Products | 149 to 249 R$ | Later | Only for earnable, balanced species |
| 10 | Emote Pack | Game Pass | 149 R$ | Later | Needs emote animations |
| 11 | Season Track | Game Pass | 399 R$ | Later | Needs seasons system |
| 12 | Supporter subscription | Subscription | ~$4.99/month equivalent | Later, optional | Cosmetic monthly drop; decide vs VIP |

Phase note: per `00-concept.md`, monetization is week 7. The **MVP** (Prototype + Core loop) ships with **no products**; it only needs the data model to have `ownedPasses`, `purchaseHistory` and `cosmetics` fields so nothing has to migrate later.

---

## 6. Analytics events (log from day one)

Use `AnalyticsService` (built-in, shows in Creator Dashboard). Server-side only. No usernames or free text in fields.

### 6.1 Onboarding funnel (`LogOnboardingFunnelStepEvent`, first session only)

| Step | Name | Fires when |
|---|---|---|
| 1 | Joined | Data loaded |
| 2 | SpeciesPicked | Hatch pressed |
| 3 | Spawned | Character in world |
| 4 | FirstDrink | First drink completes |
| 5 | FirstEat | First eat completes |
| 6 | FirstThreatEscaped | Stalker gives up |
| 7 | JournalOpened | Journal panel shown |
| 8 | ReachedJuvenile | First growth stage |
| 9 | JoinedHerd | First herd join or create |

Targets: step 6 reached by over 70% of new players; step 8 by over 35% *(tune once data exists)*.

### 6.2 Other funnels (`LogFunnelStepEvent`, with a session id per attempt)

| Funnel | Steps |
|---|---|
| Shop | 1 Opened, 2 TabViewed, 3 ItemPreviewed, 4 BuyPressed, 5 PromptShown (Robux) or ConfirmShown (coins), 6 Purchased |
| Herd invite | 1 InviteSent, 2 FriendJoined, 3 HerdJoined, 4 PlayedTogether10Min |
| Life | 1 Hatched, 2 Juvenile, 3 SubAdult, 4 Adult, 5 LaidEgg |

### 6.3 Economy (`LogEconomyEvent`)

| Flow | Transaction type | Item SKU examples |
|---|---|---|
| Source | Gameplay | `survive_time`, `growth_stage`, `kill`, `instinct` |
| Source | TimedReward | `daily_forage_d1` to `d7` |
| Source | Onboarding | `journal_first_drink`, etc. |
| Source | IAP | `coinpack_s/m/l` (later) |
| Sink | Shop | `skin_<id>`, `effect_<id>`, `species_<id>` |

Always pass `endingBalance`, so balance drift and exploits show up.

### 6.4 Custom events (`LogCustomEvent`, keep under ~30 names)

| Event | Value | Custom fields (max 3) |
|---|---|---|
| Death | Life length (s) | cause, growth stage, species |
| GrowthStage | Stage index | species, minutes to reach |
| SessionEnd | Session length (s) | species, ended alive (y/n) |
| DailyForageClaimed | Calendar day | |
| PassPurchased / ProductPurchased | Robux price | product id |
| PolicyRestricted | 1 | which flag (random items, ads) |
| FavoritePromptShown | 1 | |

Retention (D1/D7/D30) comes from the Creator Dashboard; do not rebuild it.

---

## 7. Age and safety

### 7.1 Chat and groups

| Topic | Rule |
|---|---|
| Chat system | TextChatService only. Herd chat is a `TextChannel` per herd, members added with `TextChannel:AddUserAsync`, which respects each user's chat settings and Roblox's age-based chat rules. Never build a custom chat that bypasses filtering. |
| Age-based chat | Roblox moved to age-checked chat with age groups during 2025 to 2026 (players can only chat with similar age groups unless trusted). Assume some herd members **cannot chat with each other**, and design herds to work without text: map pings, roar calls, emotes, fixed quick-chat phrases ("Follow me", "Danger", "Food here"). *(Verify the current rules before launch.)* |
| Player-written text | Dino names and herd names go through `TextService:FilterStringAsync` and are shown with the broadcast filter. Or skip custom names in MVP and use generated names ("Swift Moss Raptor"). Recommend generated names for MVP. |
| Herd invites | Opt-in accept dialog; "Block invites" toggle; leader can kick; blocked users never see your invites. |
| Reporting | Roblox's built-in report flow plus an in-game "Report exploit" with predefined reasons (no free text) that logs server-side. |

### 7.2 Violence level and Content Maturity label

Goal: **"Mild"** maturity label, so the game stays open to all ages, including under-9 players (who are limited to Minimal and Mild content).

| Area | Keep it Mild by | Avoid |
|---|---|---|
| Combat | Blocky dinos, stylised bite and swipe animations, hit flash, knockback, damage numbers optional | Realistic wounds, dismemberment |
| Blood and bleeding | Bleeding shown as a status icon plus dark-red blocky particle puffs (cartoon, few, short-lived) | Realistic red blood, pools, splatter decals |
| Death | Dino tips over, fades; leaves a blocky **carcass** (stylised meat-block and bones model) | Gore, flesh textures |
| Eating carcasses | Chomp animation, meat chunks shrink, "nom" sound | Tearing flesh, realistic sounds |
| Fear | Night is darker, roars are loud, no jump scares | Horror stingers, screaming |

Fill in the Maturity and Compliance questionnaire honestly (violence: repeated, unrealistic; blood: unrealistic, light). If playtests push toward realistic blood or gore, the label goes to Moderate (9+), which shrinks reach. *(Re-check the label definitions at launch; they were updated in 2024 to 2025.)*

### 7.3 Spending safety for a young audience

- Every Robux purchase uses Roblox's native prompt (parental spend limits apply automatically).
- No real-money price comparisons or "best value" banners in the first session; the shop is not shown until after the first threat.
- Purchase history visible to the player in Settings, so a parent can see what was bought.

---

## 8. Title ideas (original, check for conflicts before use)

| Title | Tone |
|---|---|
| **Primal Blocks** | Short, says blocky plus dinos |
| **Hatch to Apex** | Says the growth loop |
| **Brickjaw Island** | Playful, memorable |
| **Dino Dawn: Survive** | Search-friendly ("dino", "survive") |

Search the Roblox catalog and trademark databases for each before choosing.

---

## Decisions for the user

1. **Instant growth, revive, nest respawn and growth boosts as paid products.**
   Options: (a) drop all of them; (b) keep revive at a high price; (c) keep growth boosts capped at +25%.
   **Recommend (a).** In a PvP survival game these sell wins, and they will poison reviews and retention.

2. **Premium currency.**
   Options: (a) Fossil Coins plus direct Robux prices; (b) add a Robux-bought premium currency.
   **Recommend (a).** Clearer for kids, simpler to build, safer under policy.

3. **Paid random items (crates or eggs).**
   Options: (a) none at launch, revisit after 3 months; (b) cosmetic-only crates with odds shown and a PolicyService fallback shop; (c) never.
   **Recommend (a).** The rotating fixed-price shop covers the same need.

4. **Premium or Robux-only species.**
   Options: (a) every species earnable with coins, optional Robux shortcut for species earnable in about 6 hours; (b) some species Robux-only but balanced; (c) Robux-only stronger species.
   **Recommend (a).** Turn the "crystal dino" into a premium skin set.

5. **Saved dino slots (growth persists between sessions, death resets the slot).**
   Options: (a) 3 free slots plus a +3 pass; (b) 1 free slot plus a pass; (c) no saving, every session starts as a hatchling.
   **Recommend (a).** It is the strongest return hook. Needs game-designer sign-off on growth time.

6. **Private server progression.**
   Options: (a) progression saves only when settings are default; (b) never saves; (c) always saves.
   **Recommend (a).**

7. **Target Content Maturity label.**
   Options: (a) Mild, stylised violence, no realistic blood; (b) Moderate, more realistic combat, 9+.
   **Recommend (a)** for maximum reach.

8. **Daily login style.**
   Options: (a) calendar that advances on login days and never resets; (b) consecutive streak that resets after a missed day.
   **Recommend (a).** Gentler for the audience, with nearly the same return effect.

9. **Custom dino names in MVP.**
   Options: (a) generated names only; (b) filtered custom names.
   **Recommend (a)** for MVP, add (b) later.

10. **Game title.** Pick from section 8 or propose another. Recommend **Primal Blocks** or **Hatch to Apex**, after a conflict check.

11. **Platform facts to verify before week 7 (monetization).** Creator Rewards (replacement for Premium Payouts), regional pricing, subscriptions, rewarded ads eligibility, age-based chat rules and current paid-random-item rules. I flagged each as uncertain where my knowledge may be out of date. Recommend a one-hour check against Roblox's Creator Hub docs before building purchases.
