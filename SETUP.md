# Setup

Everything installs in the Claude Code cloud container, not on your Mac. `setup.sh` has the exact commands.

## Installed versions (verified 2026-11-20)

| Tool | Version | Used for | Smoke test |
|---|---|---|---|
| Node.js | v22.23.5 | HyperFrames runtime | — |
| npm | 10.9.9 | — | — |
| Python | 3.13.18 (pip 24.0) | Whisper, yt-dlp | — |
| git | 2.43.0 | — | — |
| FFmpeg | 6.1.1-3ubuntu5 | cuts, audio, export | ✅ 2 s `testsrc` + 440 Hz sine clip (H.264/AAC) |
| yt-dlp | 2026.10.26 | reference downloads | ✅ `--simulate` on a public MP4 (see note) |
| openai-whisper | 20250625 (torch 2.15.0+cpu) | captions | ✅ `tiny` model: "Hello world, this is a test on the video pipeline." |
| HyperFrames CLI | 0.9.72 | motion graphics | ✅ `hyperframes init` + `lint`: 0 errors, 0 warnings |
| HyperFrames skills | 9 skills in `.claude/skills/` | Claude Code skills | installed (`skills-lock.json`) |

## Rerun the setup in a new session

```bash
bash setup.sh
```

Use `SKIP_SMOKE=1 bash setup.sh` to skip the smoke tests. The script is safe to rerun: it skips anything already installed.

## Network requirements

The cloud environment **video-pipeline** allows these hosts beyond the default package registries:

- `download.pytorch.org`, `download-r2.pytorch.org`: CPU-only PyTorch wheels. Without them, pip pulls about 5 GB of CUDA libraries.
- `openaipublic.azureedge.net`: Whisper model weights.
- `www.youtube.com`, `youtube.com`, `vimeo.com`, `player.vimeo.com`: for yt-dlp.

If you start a session on the **Default** environment instead, the Whisper model download and the CPU torch install will fail.

## Known limitations

- **yt-dlp and YouTube/Vimeo:** both sites are reachable, but from cloud IPs they answer "Sign in to confirm you're not a bot" (YouTube) or "only works when logged-in" (Vimeo). Getting past this needs browser cookies (`--cookies`), which this setup doesn't use. yt-dlp itself works: it resolves public direct-video URLs. Download reference videos from YouTube on a machine that has cookies, or provide a cookies file yourself.
- **Whisper on CPU:** `tiny` and `base` are fast. `small` and larger are slow on 4 vCPUs.
- **HyperFrames skills** live in `.claude/skills/`, so Claude Code loads them in every session on this repo. To refresh them: `npx skills add heygen-com/hyperframes --skill '*' --agent claude-code --copy -y`.
