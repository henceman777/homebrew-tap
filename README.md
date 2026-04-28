# homebrew-tap

Homebrew formulae for [MeeTap](https://github.com/henceman777/meetap) — macOS meeting recorder with auto-transcription and AI meeting notes.

## Install

```bash
# Install virtual audio driver (required)
brew install --cask blackhole-2ch

# Install meetap
brew install henceman777/tap/meetap
```

## Prerequisites

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- AWS account with Transcribe + Bedrock + S3 permissions

## Usage

```bash
meetap start          # Start recording
meetap stop           # Stop recording, transcribe, generate notes
meetap status         # Show current status
meetap config init    # Initialize config file
```
