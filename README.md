# London Turf Wars

A Roblox turf-war game. The code lives in `src/` and is synced into Roblox Studio with **Rojo**.
See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the design brief.

## Folder layout
| In this repo | Shows up in Studio as |
|---|---|
| `src/shared/` | `ReplicatedStorage > Shared` (code that both server and players can read) |
| `src/server/` | `ServerScriptService > Server` (code only the server runs) |

File endings tell Rojo what kind of script to make:
- `Name.server.luau` becomes a **Script** (runs on the server)
- `Name.client.luau` becomes a **LocalScript** (runs on each player's computer)
- `Name.luau` becomes a **ModuleScript** (a library that other scripts `require`)

## One-time setup
1. Install **Visual Studio Code** (code.visualstudio.com).
2. In VS Code, open the Extensions panel (the four-squares icon), search for **Rojo** (by evaera) and install it.
3. Open this project folder in VS Code. Then press `Ctrl+Shift+P` (`Cmd+Shift+P` on Mac),
   type **Rojo: Open menu**, and accept when it offers to install Rojo and the Studio plugin.
4. Restart Roblox Studio. You should now see a **Rojo** button on the **Plugins** tab.

## Every time you work on the game
1. In VS Code, open **Rojo: Open menu** and click **default.project.json** to start the server.
2. In Studio, open your place, click **Plugins > Rojo**, then **Connect**.
3. Code changes in VS Code now appear in Studio straight away.
4. **Save your place file in Studio** (`File > Save to File` or publish it). Rojo syncs code,
   but the 3D map you build in Studio is saved in the place, not in this repo.
