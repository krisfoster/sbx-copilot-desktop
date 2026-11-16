#!/bin/bash
# Offline checks (no Docker, no sbx): shellcheck, syntax, and static assertions on the kit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
note() { printf '%s\n' "$*"; }
check() { if "$@"; then note "ok   ${*:0:100}"; else note "FAIL ${*:0:100}"; fail=1; fi; }

KIT=copilot-desktop
BIN=$KIT/overlay/opt/copilot-desktop/bin
SCRIPTS=(run-copilot scripts/test.sh scripts/publish.sh "$BIN/copilot-session" "$BIN/copilot-bus")

note "== shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning "${SCRIPTS[@]}"; then note "  clean"; else fail=1; fi
else
  note "  shellcheck not installed; skipping"
fi

note "== bash -n =="
for f in "${SCRIPTS[@]}"; do check bash -n "$f"; done

note "== static: kit is v3 and least-privilege =="
check bash -c "head -1 $KIT/$KIT.yaml | grep -qx '# syntax=docker/sandbox-kit:3'"
check grep -qx 'schemaVersion: "3"' "$KIT/$KIT.yaml"
check grep -q 'com.docker.sandbox/sbx@1' "$KIT/$KIT.yaml"
check bash -c "! grep -q 'install:' $KIT/$KIT.yaml"
check bash -c "! grep -qE '^[[:space:]]*- (\"?\\*\\*?\"?)\$' $KIT/$KIT.yaml"
check bash -c "! grep -rqE 'remote-debugging|BEGIN (RSA |EC )?PRIVATE KEY' $KIT run-copilot"
check grep -q -- '--password-store=gnome-libsecret' "$BIN/copilot-bus"
check grep -q -- '--app=' "$BIN/copilot-bus"
check bash -c "run=\$(grep -c '^ENTRYPOINT' $KIT/$KIT.dockerfile); [ \"\$run\" = 1 ]"

if [ "$fail" -ne 0 ]; then note "FAILED"; exit 1; fi
note "ALL CHECKS PASSED"
