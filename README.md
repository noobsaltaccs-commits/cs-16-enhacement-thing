# CS 1.6 — Gore Enhanced 🩸

A server-side [AMX Mod X](https://www.amxmodx.org/) plugin for **Counter-Strike 1.6**
that cranks the carnage up to 11: bigger blood, blood pools, and flying giblets —
using only the game's stock resources, so **players need zero downloads**.

## Features

| Effect | What you get |
| --- | --- |
| 🩸 **Extra blood on hit** | Directional blood streams + droplet sprays on every bullet/knife hit, scaled by damage. Headshots gush harder. |
| 🧱 **Blood decals** | Splat decals near wounded players and big pool decals under corpses. |
| 💀 **Giblets on death** | Bodies burst into fleshy gibs with physics (stock `fleshgibs.mdl` / `hgibs.mdl`). **Grenade kills = double gibs.** |
| 🎯 **Headshot pop** | Skull chunks + an arterial gush from the neck on headshot kills. |
| 🔴 **Screen flash** | Victims get a brief red flash, intensity scaled by the damage taken. |
| 🔥 **Extreme mode** | `amx_gore_mode 2` doubles everything for maximum mayhem. |

All effects degrade gracefully: if a stock model or sprite is missing on your
install, that specific effect is skipped and everything keeps working.

## Requirements

- Counter-Strike 1.6 dedicated or listen server
- [AMX Mod X](https://www.amxmodx.org/downloads.php) **1.8.3+** (1.9 / 1.10 recommended)
- `fakemeta` module enabled (it is by default)

## Installation

1. Copy the plugin into your server:

   ```
   addons/amxmodx/plugins/cs16_gore_enhanced.amxx
   ```

2. Add this line at the bottom of `addons/amxmodx/configs/plugins.ini`:

   ```
   cs16_gore_enhanced.amxx
   ```

3. (Optional) Load the tuned defaults — add to `amxx.cfg`:

   ```
   exec addons/amxmodx/configs/cs16_gore_enhanced.cfg
   ```

4. Change map or restart the server. Done — go make a mess. 🧹

## Configuration (CVars)

| CVar | Default | Description |
| --- | --- | --- |
| `amx_gore_mode` | `1` | Master switch: `0` off, `1` normal, **`2` EXTREME** |
| `amx_gore_blood` | `1` | Extra blood streams & sprays |
| `amx_gore_decals` | `1` | Blood splat / pool decals |
| `amx_gore_gibs` | `1` | Gib bodies on death |
| `amx_gore_gibcount` | `6` | Base giblets per death (1–32, ×2 extreme / grenades) |
| `amx_gore_headshot` | `1` | Extra skull chunks on headshot kills |
| `amx_gore_screenflash` | `1` | Red damage flash for the victim |

**Admin command** (needs `ADMIN_CVAR` access):

```
amx_gore 2      // flip to EXTREME mode mid-game, announces in chat
amx_gore        // shows current mode
```

## Compiling from source

The `.sma` source is in `addons/amxmodx/scripting/`.

- **Web compiler:** drop it into https://www.amxmodx.org/webcompiler.cgi
- **Local:** download the AMXX 1.9/1.10 base package, then:

  ```sh
  AMXX_SCRIPTING=/path/to/addons/amxmodx/scripting ./tools/compile.sh
  ```

## Notes & compatibility

- Uses only stock `models/fleshgibs.mdl`, `models/hgibs.mdl`,
  `sprites/blood(spray).spr` and the stock blood decals (indexes 190–204 in
  `decals.wad`). If your server ships a **custom decals.wad** and decals look
  wrong, tweak the `SMALL_BLOOD_DECALS` / `BIG_BLOOD_DECALS` arrays at the top
  of the source and recompile.
- Blood decals are client-limited by `r_decals` — if decals vanish quickly,
  raise `r_decals` on the client.
- Want even more? Drop custom blood `.spr` files into your `cstrike/sprites`
  folder on the client for a purely cosmetic local override.

## License

MIT — see [LICENSE](LICENSE). Made for fun with Arena.ai Agent Mode.
