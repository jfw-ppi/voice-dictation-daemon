# Voice Dictation Daemon

Tracked source for the global push-to-talk speech-to-text daemon currently used on this Ubuntu desktop.

## What It Does

- Listens globally for `F8`
- Starts and stops microphone capture with `arecord`
- Transcribes audio with either a local `faster-whisper` model or the OpenAI transcription API
- Types the resulting text into the currently focused text field
- Runs as a `systemd --user` service

## Repo Layout

- `bin/voice-dictation-daemon`: current daemon script
- `systemd/user/voice-dictation.service`: current user service unit
- `config/voice-dictation.env.example`: non-secret config template
- `requirements.txt`: Python package dependencies

## Runtime Dependencies

- Python 3
- `arecord` from `alsa-utils`
- A working X11 session
- Python packages from `requirements.txt`

The local backend currently depends on:

- `faster-whisper`
- `pynput`

The optional remote backend depends on:

- `openai`

## Current Live Setup

The live machine currently uses:

- daemon at `~/.local/bin/voice-dictation-daemon`
- config at `~/.config/voice-dictation.env`
- optional secret config at `~/.config/voice-dictation.secret.env`
- service unit at `~/.config/systemd/user/voice-dictation.service`
- logs at `~/.local/state/voice-dictation/daemon.log`

This repo intentionally tracks the current app state without committing secrets. The tracked source has been sanitized to use home-relative paths instead of machine-specific `/home/...` values.

## Install Or Update From Repo

1. Create or activate a Python environment and install dependencies:

```bash
python3 -m venv ~/.local/share/voice-dictation/venv
~/.local/share/voice-dictation/venv/bin/pip install -U pip
~/.local/share/voice-dictation/venv/bin/pip install -r requirements.txt
```

2. Install the daemon and service:

```bash
install -Dm755 bin/voice-dictation-daemon ~/.local/bin/voice-dictation-daemon
install -Dm644 systemd/user/voice-dictation.service ~/.config/systemd/user/voice-dictation.service
install -Dm600 config/voice-dictation.env.example ~/.config/voice-dictation.env
```

3. Reload and restart the user service:

```bash
systemctl --user daemon-reload
systemctl --user enable --now voice-dictation.service
systemctl --user restart voice-dictation.service
```

## Configuration

Copy `config/voice-dictation.env.example` to `~/.config/voice-dictation.env` and adjust:

- `VOICE_DICTATION_BACKEND=local` for local `faster-whisper`
- `VOICE_DICTATION_BACKEND=openai` for OpenAI transcription
- `VOICE_DICTATION_MODEL=turbo` for the current local model default
- `VOICE_DICTATION_OPENAI_MODEL=gpt-4o-transcribe` or `gpt-4o-mini-transcribe` for remote transcription

For OpenAI, place the key in `~/.config/voice-dictation.secret.env`:

```bash
OPENAI_API_KEY=<your-api-key>
```

That file is intentionally ignored by Git.

## Usage

- Press `F8` once to start recording
- Press `F8` again to stop and transcribe
- Focus any text field before dictating

## Notes

- The repo version uses `Path.home()` and `%h` so it can be published without exposing a machine-specific home path.
- The current implementation is intended for X11. It has not been adapted for Wayland yet.
- If the OpenAI backend is enabled, the API account must have available quota.
