"""PostToolUse hook: run `dart format` on an edited .dart file."""
import json
import os
import subprocess
import sys

payload = json.load(sys.stdin)
path = (payload.get("tool_input") or {}).get("file_path") or (
    payload.get("tool_response") or {}
).get("filePath")
if not path or not path.endswith(".dart") or not os.path.isfile(path):
    sys.exit(0)
subprocess.run(
    f'dart format "{path}"',
    shell=True,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
