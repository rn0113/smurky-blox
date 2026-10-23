# London Turf Wars

A Roblox turf-war game. The code lives in `src/` and is synced into Roblox Studio with
Studio's built-in **Script Sync** (a beta feature).
See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the design brief.

## Folder layout
Each folder in `src/` is synced to a Folder in Studio:

| In this repo | Synced to this Folder in Studio |
|---|---|
| `src/shared/` | `ReplicatedStorage > Shared` (code that both the server and players can read) |
| `src/server/` | `ServerScriptService > Server` (code that only the server runs) |
| `src/client/` | `StarterPlayer > StarterPlayerScripts > Client` (code that runs on each player's computer, e.g. on-screen menus) |

The Studio folder names (`Shared`, `Server`, `Client`) matter, because scripts refer to them by name.

File endings tell Script Sync what kind of script to make:
- `Name.server.luau` becomes a **Script** that runs on the server
- `Name.client.luau` becomes a **Script** that runs on each player's computer
- `Name.luau` becomes a **ModuleScript** (a library that other scripts `require`)

## One-time setup
1. Get this repo onto your computer. The easiest way is **GitHub Desktop**: **File > Clone repository**,
   pick `smurky-blox`, then switch to the branch you're working on with the **Current branch** button.
2. In Studio, turn on **File > Beta Features > Script Sync** and restart Studio.
3. In your place, create the three Folders listed in the table above (right-click the service in
   **Explorer** > **Insert Object** > **Folder**, then rename it).
4. Right-click each Folder and choose the Script Sync option. Point it at the matching folder in `src/`.
   If Studio asks which side to keep, choose the **files on disk**, because the code in this repo is the master copy.

## Every time you work on the game
- Script Sync keeps Studio and the files in `src/` in step automatically.
- Commit and push from GitHub Desktop to save your code.
- **Save your place file** too (`File > Publish to Roblox`). Script Sync only syncs scripts.
  The 3D map, lighting and models are saved in the place file, not in this repo.

## Building the bases and chop shops
`src/server/MapBuilder.luau` builds detailed crew bases and chop shops straight into your map.
You run it once from the Command Bar, and the result is saved in your place file.

1. Stop any playtest. Open **View > Command Bar** (a text box at the bottom of Studio).
2. For crew bases, make sure each crew has its SpawnLocation (TeamColor set, Neutral unticked),
   standing on open, flat ground with about 80 × 80 studs of space. The spawn's front faces where the gate will go.
   For a chop shop, place any part where you want the doors and click it so it's selected.
3. Paste one line into the Command Bar and press Enter:
   ```lua
   require(game.ServerScriptService.Server.MapBuilder).lighting()
   require(game.ServerScriptService.Server.MapBuilder).allCrewBases()
   require(game.ServerScriptService.Server.MapBuilder).chopShop()
   ```
   `crewBase("MudlarkMob")` builds just one base. `chopShop("MudlarkMob")` uses that crew's colours.
4. Don't like it? Press **Ctrl+Z**. Running `crewBase` again replaces that crew's old generated base.
   It never deletes things you built yourself.
5. **Publish** the place so the new buildings are saved.

If you change the builder code, restart Studio before running it again. The Command Bar
remembers the old version of a module until then.

## Outfits
`src/shared/OutfitConfig.luau` sets what each team wears. Every player automatically gets
crew-coloured gear (armband + chest badge), and the Police get a stab vest. To add matching uniform
clothing, put a Shirt or Pants asset ID into `ShirtId` / `PantsId` for each team (0 = keep the player's own).

## Shop employees and robberies
Every chop shop built by `MapBuilder` has a counter with an employee behind it. Walk up to them:
- **[E] Talk**: a friendly chat. Police players get an extra "Seen anything suspicious?" option.
- **[F] Rob** (hold): crews only. Pick what to say from the dialogue panel; your choice decides the payout.
  Stay close while the till is emptied. Police get an alert as soon as a robbery starts.

All dialogue lines, names and payouts are in `src/server/ShopConfig.luau`. Its top comment explains how to
write new dialogue scripts.

To put an employee in a shop you built yourself, insert a small Part where they should stand (facing the
counter), and add the tag `ShopEmployee` under **Properties > Tags**. You can also add the attributes `ShopName` and `EmployeeName`.
Chop shops built before this update don't have the counter, so run `chopShop()` again for those.
