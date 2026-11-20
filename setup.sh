#!/usr/bin/env bash
# Install the video-pipeline toolchain: FFmpeg, yt-dlp, Whisper (CPU), HyperFrames.
# Safe to rerun. Written for the Ubuntu-based Claude Code cloud container (runs as root).
#
#   bash setup.sh            # install everything, then run smoke tests
#   SKIP_SMOKE=1 bash setup.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
PIP="python3 -m pip install -U --break-system-packages"

echo "==> 1. Prerequisites (Node 22+, Python 3 + pip, git)"
NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/' || echo 0)
if [ "${NODE_MAJOR:-0}" -lt 22 ]; then
  echo "Node ${NODE_MAJOR} < 22, installing Node 22 from NodeSource"
  curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO bash -
  $SUDO apt-get install -y nodejs
fi
command -v git >/dev/null || { $SUDO apt-get update -qq; $SUDO apt-get install -y git; }
python3 -m pip --version >/dev/null 2>&1 || { $SUDO apt-get update -qq; $SUDO apt-get install -y python3-pip; }

echo "==> 2. FFmpeg (+ espeak-ng, used only to make a spoken test clip)"
if ! command -v ffmpeg >/dev/null || ! command -v espeak-ng >/dev/null; then
  $SUDO apt-get update -qq
  $SUDO apt-get install -y ffmpeg espeak-ng
fi

echo "==> 3. yt-dlp"
$PIP yt-dlp

echo "==> 4. Whisper with CPU-only PyTorch"
# Installing torch from the CPU index first keeps pip from pulling ~5 GB of CUDA wheels.
# Needs download.pytorch.org and download-r2.pytorch.org on the network allowlist.
if ! python3 -c "import torch,sys; sys.exit(0 if '+cpu' in torch.__version__ else 1)" 2>/dev/null; then
  $PIP torch --index-url https://download.pytorch.org/whl/cpu
fi
$PIP openai-whisper
# Remove leftover CUDA libraries if a CUDA build of torch was installed earlier.
CUDA_PKGS=$(python3 -m pip list 2>/dev/null | awk '/^(nvidia-|cuda-)/{print $1}')
[ -n "$CUDA_PKGS" ] && python3 -m pip uninstall -y --break-system-packages $CUDA_PKGS
# Pre-download the tiny model (from openaipublic.azureedge.net) into ~/.cache/whisper.
python3 -c "import whisper; whisper.load_model('tiny', device='cpu')"

echo "==> 5. HyperFrames CLI + agent skills"
npm install -g hyperframes
# The skills are committed under .claude/skills. This refreshes them from upstream.
(cd "$REPO_DIR" && npx -y skills add heygen-com/hyperframes --skill '*' --agent claude-code --copy -y)

echo "==> Versions"
node -v; npm -v; python3 --version; git --version
ffmpeg -version | head -1
echo "yt-dlp $(yt-dlp --version)"
python3 -m pip show openai-whisper | sed -n '1,2p'
python3 -c "import torch; print('torch', torch.__version__)"
echo "hyperframes $(hyperframes --version)"

[ "${SKIP_SMOKE:-0}" = "1" ] && exit 0

echo "==> Smoke tests"
T="$(mktemp -d)"; cd "$T"
ffmpeg -y -loglevel error -f lavfi -i testsrc=duration=2:size=640x360:rate=30 \
  -f lavfi -i sine=frequency=440:duration=2 -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest test.mp4
ffprobe -v error -show_entries format=duration -of default=nw=1 test.mp4
ffmpeg -y -loglevel error -i test.mp4 -vn -ac 1 -ar 16000 test.wav
whisper test.wav --model tiny --language en --fp16 False --output_dir out --output_format txt >/dev/null 2>&1
echo "whisper on sine clip: OK (no speech, so the transcript is empty)"
espeak-ng -w speech.wav "Hello world. This is a test of the video pipeline."
whisper speech.wav --model tiny --language en --fp16 False --output_dir out --output_format txt >/dev/null 2>&1
echo "whisper on speech clip: $(cat out/speech.txt)"
# YouTube and Vimeo ask cloud IPs to sign in, so test with a public direct MP4 instead.
yt-dlp --simulate --print "yt-dlp: %(title)s.%(ext)s" \
  "https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4" 2>/dev/null
HYPERFRAMES_SKIP_SKILLS=1 hyperframes init hf-sample --non-interactive --skip-skills >/dev/null
(cd hf-sample && hyperframes lint)
rm -rf "$T"
echo "==> All done"
