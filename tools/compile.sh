#!/bin/sh
# Compile the plugin with a locally installed AMX Mod X compiler.
#
# Usage:
#   1. Download AMX Mod X 1.9/1.10 "base" package for your OS from
#      https://www.amxmodx.org/downloads.php
#   2. Point AMXX_SCRIPTING at its scripting folder:
#        AMXX_SCRIPTING=/path/to/addons/amxmodx/scripting ./tools/compile.sh
#
# Result: addons/amxmodx/plugins/cs16_gore_enhanced.amxx

set -e

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/addons/amxmodx/scripting/cs16_gore_enhanced.sma"
OUT="$HERE/addons/amxmodx/plugins"
AMXX_SCRIPTING="${AMXX_SCRIPTING:-/opt/amxmodx/scripting}"

if [ ! -x "$AMXX_SCRIPTING/amxxpc" ]; then
    echo "error: amxxpc not found at $AMXX_SCRIPTING/amxxpc" >&2
    echo "set AMXX_SCRIPTING to your addons/amxmodx/scripting folder" >&2
    exit 1
fi

mkdir -p "$OUT"
"$AMXX_SCRIPTING/amxxpc" "$SRC" \
    -i"$AMXX_SCRIPTING/include" \
    -o"$OUT/cs16_gore_enhanced.amxx"

echo "built: $OUT/cs16_gore_enhanced.amxx"
