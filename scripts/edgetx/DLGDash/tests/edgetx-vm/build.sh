#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 2 ]]; then
  echo "Usage: build.sh /path/to/edgetx/radio/src/thirdparty/Lua/src /absolute/output/edgetx-vm" >&2
  exit 2
fi
host_dir=$(cd -- "$(dirname -- "$0")" && pwd)
source_dir=$(cd -- "$1" && pwd)
output=$2
[[ $output = /* && -f "$source_dir/lro_defs.h" ]]
build_dir=$(mktemp -d /tmp/dlg-edgetx-vm-XXXXXX)
cp -r "$source_dir" "$build_dir/lua"
cp "$host_dir/host-init.c" "$host_dir/host.c" "$host_dir/debug.h" "$host_dir/definitions.h" "$build_dir/"
cd "$build_dir"
sources=()
for module in lapi lcode lctype ldebug ldo ldump lfunc lgc llex lmem lobject lopcodes lparser lstate lstring ltable ltm lundump lvm lzio lauxlib lbaselib lbitlib lmathlib lstrlib ltablib ldblib; do
  sources+=("lua/$module.c")
done
gcc -std=gnu99 -O1 -DCOLORLCD -I lua -I . "${sources[@]}" host-init.c host.c -lm -o "$output"
