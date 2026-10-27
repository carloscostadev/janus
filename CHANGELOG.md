# Changelog

All notable changes to Janus are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Every stop, restart, "Stop all" and "Open in terminal" ends in a short status line in the popover: stopped, restarted (with the new PID), relaunched but not listening yet, the port taken by another process, not allowed, or still running.
- A notice when a scan fails ("Couldn't read ports · retrying"): the list shown may be out of date.
- "Show system processes" option in the popover footer (off by default) to list the processes the noise filter hides.
- Restart relaunches the command with the process's own environment variables (e.g. `PORT`), not only its arguments and folder.
- Opt-in end-to-end test that restarts real servers (python, node, npm run dev, a wrapper script); README image of the popover.

### Changed
- Stop and restart wait for the process to actually exit (polling instead of fixed delays) and the row shows a spinner until the action ends.

### Security
- The process identity (owner and start time) is captured at scan time: stop and restart leave a PID alone if it now belongs to a different process.
- Exited processes awaiting collection (zombies) count as gone.

## [1.1.0] - 2026-10-25

### Changed
- New brand (icon, menu bar symbol): Janus mark 1.3, the "passage" symbol (a doorway arch cut by the horizon), drawn in code. The app icon is the white symbol on a black rounded square, in the style of Thoth (`icon/gen_icon.swift`); the menu bar shows the symbol as a template image instead of the globe; the popover header shows the symbol and the JANUS wordmark.
- Redesigned interface, in the style of Thoth: one `Theme` for the light and dark palettes, type scale, spacing and cards; a header with the Janus mark and the number of listening ports in large type; hairlines between project groups; ports and PIDs in a monospaced font; row actions shown on hover, with tooltips and accessibility labels. Green and red only mark a live port and destructive actions, and every text color meets WCAG AA contrast in both themes.
- Port scans run on a background task; the menu bar UI never waits for `lsof`.
- Listening sockets come from a single `lsof` call, executed directly (no intermediate shell).
- Working directories are read natively (`proc_pidinfo`) instead of a second `lsof` call.
- Project roots are cached per directory between scans; the port list is only republished when it actually changes, and the polling timer allows the system to coalesce wakeups. Measured idle cost dropped from about 2.8% to 1.7% of one CPU core (app plus child processes).
- "Stop all" now asks for confirmation and signals each process once.
- Favorites migration from LocalPorts reads the old preferences through the system (`cfprefsd`) instead of the raw `.plist` file.
- Tailscale (`IPNExtension`) is hidden by the noise filter.
- User-visible text is localized in English and Portuguese (pt-PT).

### Fixed
- The in-app "Restart" button could leave no Janus running: the new copy saw the old one still alive and quit itself.
- Command output larger than 64 KB could hang a scan (pipe was read only after the process exited).
- A failed `lsof` run no longer blanks the port list; the last known list is kept.
- The "Launch at login" checkbox reverts to the real state when macOS refuses the change.

### Security
- Kill and restart only act on processes owned by the current user, never on launchd or Janus itself.
- The whole process group is only signalled when safe: never `kill(-1)`, never Janus's own group, another user's group or a group led by an `.app` (for example an editor that spawned the dev server).
- The delayed SIGKILL checks that the PID still belongs to the same process, so a reused PID is never hit.

### Removed
- Screenshot from the README and the unused `docs/screenshot.png`.

## [1.0.0] - 2026-05-27

### Changed
- **Renamed from LocalPorts to Janus.** Bundle identifier is now `com.carloscosta.Janus`.
- Repository moved from `carloscostadev/localports` to `carloscostadev/janus` (GitHub keeps the old URL redirecting).
- Website moved to `https://janus.carloscostadev.pt`.

### Added
- One-shot migration: on first launch, Janus copies your favorites from the previous LocalPorts app so nothing is lost.

### Notes
- The old `LocalPorts.app` (bundle ID `com.carloscosta.LocalPorts`) is unaffected and can be deleted manually after upgrading.
- All previous releases (LocalPorts v1.0.0 → v1.1.3) remain available under the old name in this repo's release history.

---

# LocalPorts (pre-rename history)

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

[Unreleased]: https://github.com/carloscostadev/janus/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/carloscostadev/janus/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/carloscostadev/janus/releases/tag/v1.0.0
