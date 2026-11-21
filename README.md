# UsageBar

A tiny floating widget for macOS that shows how much **Claude Code** and **Codex** usage you have left. Free and open source (MIT).

Each ring shows the remaining %, how long until the limit resets, and the exact reset time.
Rings turn green → orange → red as you run low. Tools with no data are hidden.

Also available in Korean: [README.ko.md](README.ko.md). The app itself follows your system language (English, Korean, Japanese, Chinese).

## Install

Paste this into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/blueblud7/usage-bar/main/install.sh | bash
```

Or download `UsageBar.zip` from [Releases](../../releases), unzip it, move `UsageBar.app` to Applications, then **right-click → Open** the first time (the app isn't notarized by Apple, so a double-click shows a warning).

A widget appears at the top right of your screen. Drag it anywhere. Right-click it to refresh, launch at login, or quit.

Requires macOS 13+ (Apple Silicon and Intel).

## What you need

- **Claude**: you must have signed in to Claude Code at least once (terminal CLI or the desktop app's Code tab). Claude.ai chat alone isn't enough.
- **Codex**: you must have used Codex at least once.
- Using just one of them is fine.

## How it works and privacy

- **Codex**: reads rate-limit info from your local logs in `~/.codex/sessions`. No network.
- **Claude**: reads the Claude Code login token from your Keychain and queries Anthropic's usage endpoint (`api.anthropic.com`) every 5 minutes. macOS asks for Keychain access the first time. Choose **Always Allow**.
- Your token is sent only to `api.anthropic.com`. It is never stored or logged elsewhere. All code is in [`Sources/UsageBar.swift`](Sources/UsageBar.swift), so you can verify it.
- Diagnostics go to `~/Library/Logs/UsageBar.log` (no tokens).

## Known limitations

- The Claude lookup uses an **unofficial, undocumented API**. It may break if Anthropic changes it.
- Claude login tokens expire after a few hours. When that happens the widget says so; use Claude Code once and the ring comes back.
- If your plan has no 5-hour limit, only the weekly limit is shown.
- Google Antigravity (`agy`) isn't supported: its quota can't be read locally.

## Build from source

```bash
./build.sh   # produces UsageBar.app and UsageBar.zip
```

Unofficial tool, not affiliated with Anthropic or OpenAI.
