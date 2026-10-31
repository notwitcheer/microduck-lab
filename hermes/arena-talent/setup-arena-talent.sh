#!/bin/bash
mkdir -p ~/Pollen/arena-talent
exec > >(tee -a ~/Pollen/arena-talent/setup.log) 2>&1
export PATH=~/.local/bin:$PATH
cd ~/Pollen/arena-talent
[ -d microduck-challenges ] || git clone https://github.com/pollen-robotics/microduck-challenges.git
[ -d microduck-arena ] || git clone https://github.com/pollen-robotics/microduck-arena.git
(cd microduck-challenges && git checkout -q 4b675eb && git log -1 --format='challenges %h %ci')
(cd microduck-arena && git checkout -q bbddfe5 && git log -1 --format='arena %h %ci')
uv python install 3.12
cd microduck-challenges && uv sync --group workshop 2>&1 | tail -n 30; echo CHAL_SYNC_RC=${PIPESTATUS[0]}
cd ~/Pollen/arena-talent
# ffmpeg for arena clip (no system ffmpeg on capsule)
uv venv --python 3.12 ffvenv 2>&1 | tail -n 2
VIRTUAL_ENV=~/Pollen/arena-talent/ffvenv uv pip install imageio-ffmpeg 2>&1 | tail -n 2
mkdir -p bin
FF=$(~/Pollen/arena-talent/ffvenv/bin/python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
ln -sf "$FF" bin/ffmpeg
bin/ffmpeg -version | head -n 1
echo SETUP_DONE
