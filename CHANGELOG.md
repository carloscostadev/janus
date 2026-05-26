# Changelog

All notable changes to LocalPorts are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.3] - 2026-05-17

### Changed
- Build now produces a universal binary (arm64 + x86_64).

## [1.1.2] - 2026-05-17

### Added
- Restart button next to quit in the menu.
- App icon with globe and port design, bundled as `AppIcon.icns` in local and CI builds.
- GitHub Actions release workflow.
- `build.sh` and `dev.sh` scripts.

### Changed
- Redesigned UI for a cleaner, more consistent visual style.
- Migrated the project from XcodeGen to Swift Package Manager.

### Fixed
- Prevent duplicate app instances from running at the same time.
- Filter out Cursor and AnyDesk from the port list.

## [1.1.1] - 2026-04-04

### Added
- Restart button next to quit.

### Fixed
- Filter Spotify from the port list.
- Kill the entire process group and improve port display.
- Show version in the menu and fix duplicate IDs for multi-port processes.

## [1.0.1] - 2026-03-29

### Fixed
- Improved port detection and grouping of multi-port projects.

## [1.0.0] - 2026-03-28

### Added
- Initial release: macOS menu bar app that monitors active localhost ports.
- Real-time port scanning with project detection (groups ports by project root).
- Process management: kill, restart, or open a port in the browser.
- Open a project directory directly in the terminal.

[1.1.3]: https://github.com/carloscostadev/localports/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/carloscostadev/localports/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/carloscostadev/localports/compare/v1.0.1...v1.1.1
[1.0.1]: https://github.com/carloscostadev/localports/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/carloscostadev/localports/releases/tag/v1.0.0
