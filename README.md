# LocalPorts

A lightweight macOS menu bar app that monitors all active localhost ports. See what's running, kill what you don't need — one click away.

[Website](https://localports.carloscostadev.pt) | [Download](https://github.com/carloscostadev/localports/releases/latest)

![LocalPorts](docs/screenshot.png)

## Features

- **Real-time port scanning** — auto-refreshes every 3s, no config needed
- **Project detection** — groups ports by project root (finds .git, package.json, go.mod, etc.)
- **Favorites** — pin frequently used ports to the top, persisted across restarts
- **Process management** — kill, restart, or open any port in the browser with one click
- **Open in terminal** — jump straight to the project directory in Warp or Terminal
- **Launch at login** — starts automatically with macOS

## Install

Download the latest `.zip` from [Releases](https://github.com/carloscostadev/localports/releases/latest), unzip, and drag `LocalPorts.app` to `/Applications`.

> On first launch, right-click the app and select "Open" to bypass Gatekeeper.

## Build from Source

```bash
git clone https://github.com/carloscostadev/localports.git
cd localports
./scripts/build.sh
```

## Development

```bash
# Open in Xcode (with SwiftUI previews)
open Package.swift

# Or build, install and run from terminal
./scripts/dev.sh
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel
- Xcode 15+ (for development only)

## License

[MIT](LICENSE)
