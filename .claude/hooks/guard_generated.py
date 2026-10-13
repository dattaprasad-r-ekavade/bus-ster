"""PreToolUse hook: keep generated files out of hand edits.

Generated l10n code and pubspec.lock are denied outright. The level pack is
only partly generated (the three tutorials are hand-authored), so edits to it
ask for confirmation instead.
"""
import json
import re
import sys

payload = json.load(sys.stdin)
path = ((payload.get("tool_input") or {}).get("file_path") or "").replace("\\", "/")

RULES = [
    (
        r"lib/l10n/app_localizations[^/]*\.dart$",
        "deny",
        "Generated file. Edit lib/l10n/app_en.arb, then run `flutter gen-l10n`.",
    ),
    (
        r"(^|/)pubspec\.lock$",
        "deny",
        "Lock file. Change pubspec.yaml, then run `flutter pub get`.",
    ),
    (
        r"assets/levels/jam_levels\.json$",
        "ask",
        "Levels 4+ are generated: run `dart run tools/generate_jam_levels.dart` "
        "then `dart run tools/validate_jam_levels.dart`. Hand-edit only the "
        "tutorials, keeping vehicles in plan order.",
    ),
]

for pattern, decision, reason in RULES:
    if re.search(pattern, path):
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": decision,
                        "permissionDecisionReason": reason,
                    }
                }
            )
        )
        break
