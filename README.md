# wow-addons

Personal addons for World of Warcraft: Forever (Lua 5.1, modern Midnight UI API, `## Interface: 16001`).

| Addon | What it does |
|---|---|
| [TrainerBook](TrainerBook/README.md) | Class spells by level and profession recipes by skill, with trainer costs recorded in game (`/tb`) |

## Workflow

Each top-level folder is one addon; the folder name must match its `.toc`.

```bash
./deploy.sh              # copy all addons into the game's AddOns folder
./deploy.sh TrainerBook  # or just one
```

Then `/reload` in game (a changed `.toc` needs a client restart). The game folder defaults to
`/mnt/d/Games/World of Warcraft/_forever_/Interface/AddOns`; override with `WOW_ADDONS_DIR`.
Never edit the copies in the game folder — `deploy.sh` overwrites them.

Useful in game: `/console scriptErrors 1`, `/dump <expr>`, `/fstack`, `/etrace`.
