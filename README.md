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

The Studio folder names (`Shared`, `Server`) matter, because scripts refer to them by name.

File endings tell Script Sync what kind of script to make:
- `Name.server.luau` becomes a **Script** that runs on the server
- `Name.client.luau` becomes a **Script** that runs on each player's computer
- `Name.luau` becomes a **ModuleScript** (a library that other scripts `require`)

## One-time setup
1. Get this repo onto your computer. The easiest way is **GitHub Desktop**: **File > Clone repository**,
   pick `smurky-blox`, then switch to the branch you're working on with the **Current branch** button.
2. In Studio, turn on **File > Beta Features > Script Sync** and restart Studio.
3. In your place, create the two Folders listed in the table above (right-click the service in
   **Explorer** > **Insert Object** > **Folder**, then rename it).
4. Right-click each Folder and choose the Script Sync option. Point it at the matching folder in `src/`.
   If Studio asks which side to keep, choose the **files on disk**, because the code in this repo is the master copy.

## Every time you work on the game
- Script Sync keeps Studio and the files in `src/` in step automatically.
- Commit and push from GitHub Desktop to save your code.
- **Save your place file** too (`File > Publish to Roblox`). Script Sync only syncs scripts.
  The 3D map, lighting and models are saved in the place file, not in this repo.
