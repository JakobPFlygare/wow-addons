# TrainerBook (WoW Forever)

Personal addon: class spells by level (every rank, tooltip, cost) and profession recipes by skill (sort, categories, filters).

- `/tb` (or the addon-compartment button) opens it. `/tb scan` rescans an open trainer, `/tb stats` counts recorded costs, `/tb reset` clears saved data.
- **Spell/recipe lists** are bundled in `Data/*.lua`, generated from wowforevertalents.com, which reads them from the Forever client.
- **Costs** are not in any public source. The addon records them when a trainer window is open (all services, including future ranks and recipes above your skill), so visiting your class trainer and each profession trainer once fills them in. Recorded costs include your reputation discount.
- Shift-click a row to link the spell in chat (once its spell id is known). Hold Shift over a recipe for the crafted item.

## Refresh data after a patch

```bash
cd ~/gitrepos-personal/wow-addons
python3 TrainerBook/tools/build_data.py --refresh
./deploy.sh TrainerBook
```

Then `/reload` in game.
