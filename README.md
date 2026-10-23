# Janus

[![Latest Release](https://img.shields.io/github/v/release/carloscostadev/janus)](https://github.com/carloscostadev/janus/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/carloscostadev/janus/total)](https://github.com/carloscostadev/janus/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Swift](https://img.shields.io/badge/swift-5.9-orange)

A lightweight macOS menu bar app that monitors all active localhost ports. See what's running, kill what you don't need - one click away.

[Website](https://janus.carloscostadev.pt) | [Download](https://github.com/carloscostadev/janus/releases/latest)

> Janus is the Roman god of doorways, gates, and transitions - fitting for an app that watches every port open on your machine.
> Previously released as **LocalPorts**; renamed in v1.0.0 (favorites are migrated automatically on first launch).

## Features

- **Real-time port scanning** - auto-refreshes every 3s, no config needed
- **Project detection** - groups ports by project root (finds `.git`, `package.json`, `Gemfile`, `composer.json`, `go.mod`)
- **Favorites** - pin frequently used ports to the top, persisted across restarts
- **Process management** - kill, restart, or open any port in the browser with one click ("Stop all" asks for confirmation; only your own processes can be signalled)
- **Open in terminal** - jump straight to the project directory in Warp or Terminal
- **Launch at login** - starts automatically with macOS
- **Noise filter** - hides system processes (ControlCenter, rapportd, Spotify, Cursor, AnyDesk, GitHub Desktop, Tailscale, etc.)
- **Lightweight** - one `lsof` call per scan, working directories read natively; under 2% of one CPU core on average while idle
- **English and Portuguese (pt-PT)** - follows the macOS language

## Install

Download the latest `.zip` from [Releases](https://github.com/carloscostadev/janus/releases/latest), unzip, and drag `Janus.app` to `/Applications`.

Janus is open source and not notarized by Apple, so macOS asks for confirmation on first launch:

- **macOS 15 or later:** try to open Janus, then go to **System Settings > Privacy & Security** and click **Open Anyway**.
- **macOS 14:** right-click `Janus.app` and choose **Open**.
- **Terminal (any version):** `xattr -dr com.apple.quarantine /Applications/Janus.app`

## Build from Source

```bash
git clone https://github.com/carloscostadev/janus.git
cd janus
./scripts/build.sh
```

## Development

```bash
# Open in Xcode (with SwiftUI previews)
open Package.swift

# Run the tests
swift test

# Or build, install to /Applications and run from terminal
./scripts/dev.sh
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel
- Xcode 16+ / Swift 6 toolchain (for development only; tests use Swift Testing)

## License

[MIT](LICENSE)
