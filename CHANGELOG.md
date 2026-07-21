# Changelog

## [1.0.1] - 2026-07-21

Compatibility hardening after a reported startup crash:

- Dropped pcvar API for the classic cvar API — plugin now loads on
  AMXX 1.8.0+ (no more `get_pcvar_num` requirement)
- Precaching now skips missing *and suspiciously small/corrupt* stock
  files (corrupt models precached at map start crash the engine with
  Host_Error on some installs)
- Added "Troubleshooting" section to the README
- Rebuilt `.amxx`; binary structure re-validated against the AMXX
  loader's format expectations

## [1.0.0] - 2026-07-21

Initial release.

- Extra blood streams and droplet sprays on every hit (damage-scaled)
- Blood splat decals on hits, pool decals under corpses
- Fleshy giblets with physics on death (stock gore models, no downloads)
- Grenade kills deal double gibs and extra pools
- Headshot kills: skull chunks + arterial gush
- Damage-scaled red screen flash for victims
- `amx_gore_mode` (off / normal / EXTREME) + `amx_gore` admin command
- Graceful fallback when optional stock resources are missing
