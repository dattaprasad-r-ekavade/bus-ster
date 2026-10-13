#!/usr/bin/env bash
# Bus-ster verification gate: runs every step, reports each, exits non-zero on any failure.
cd "$(git rev-parse --show-toplevel)" || exit 1

status=0
step() {
  local name="$1"; shift
  local log
  log="$(mktemp)"
  if "$@" >"$log" 2>&1; then
    echo "PASS  $name  ($(tail -n 1 "$log"))"
  else
    echo "FAIL  $name"
    tail -n 40 "$log" | sed 's/^/      /'
    status=1
  fi
  rm -f "$log"
}

step "format"    dart format --set-exit-if-changed lib test tools integration_test test_driver
step "analyze"   flutter analyze
step "test"      flutter test
step "levels"    dart run tools/validate_jam_levels.dart
step "doc links" python tools/check_links.py
exit $status
