---
name: demo-video
description: Record a demo video of Bus-ster on the Android emulator by running the scripted demo tour (home, three tutorials, pause menu, dense level 12) while screen-recording, then encode a 720p MP4 and a contact sheet. Boots the Busster_QA_API35 emulator if needed.
disable-model-invocation: true
---

# Record a Bus-ster demo video

```bash
bash .claude/skills/demo-video/record_demo.sh [output_dir]
```

Default output is `build/demo/` (ignored by git). The script:

1. Boots the `Busster_QA_API35` AVD if `emulator-5554` isn't online (override with
   `BUSSTER_AVD` / `BUSSTER_DEVICE`). The emulator sometimes exits on its own between
   runs; rerunning the script reboots it.
2. Clears app data so the tour starts from a fresh home screen.
3. Runs `integration_test/demo_tour_test.dart`, starting `screenrecord` only once the
   app process exists.
4. Pulls the recording, trims the splash, encodes `busster_demo_<timestamp>.mp4`
   (720p H.264), and writes a contact sheet PNG.

After it finishes:

- Read the contact sheet image and check it really shows gameplay (buses moving, the
  win overlay, level 12). A passing test does not prove the recording captured it.
- Open the video for the user: `cmd.exe //c start "" "$(cygpath -w <video path>)"`.
- Report the video path. QA videos and screenshots belong in PRs, not the repo.

Requires `ffmpeg` on PATH and the Android SDK at `%LOCALAPPDATA%\Android\sdk` (or
`ANDROID_SDK_ROOT`).
