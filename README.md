<h1 align="center">Peek</h1>

<p align="center">
  Instant AI-powered Jira ticket summaries from your menu bar
</p>

<p align="center">
  <a href="https://github.com/adammiribyan/peek/releases/latest"><img src="https://img.shields.io/github/v/release/adammiribyan/peek?style=for-the-badge&labelColor=000000" alt="Release" /></a>
  <a href="https://github.com/adammiribyan/peek/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-000000?style=for-the-badge&labelColor=000000" alt="License" /></a>
  <a href="https://github.com/adammiribyan/peek"><img src="https://img.shields.io/badge/macOS_26+-000000?style=for-the-badge&labelColor=000000" alt="macOS 26+" /></a>
</p>

<br />

<p align="center">
  <img src="assets/demo.gif" alt="Peek demo" width="960" />
</p>

<br />

Hit **⌘⇧J** from anywhere, type a ticket number, and get an AI-generated summary in a floating card — without switching windows or opening a browser.

Open multiple tickets. Click linked issues to follow the thread. Every ticket gets a risk assessment dot. It just works.

## Features

- **AI summaries** — streaming markdown summaries powered by Claude, with smart caching
- **Risk assessment** — green/yellow/red dot on every ticket based on scope, complexity, and status
- **Linked issues** — compact chips showing blocked-by, relates-to, and other Jira links; click to open
- **PR status** — see linked pull requests and their review state
- **Project autocomplete** — type a project prefix and tab-complete from your Jira projects
- **Multiple panels** — open as many tickets as you want, each in its own floating glass panel
- **Jira OAuth 2.0** — secure three-legged OAuth flow, no API tokens to manage
- **Auto-updates** — checks GitHub Releases and prompts when a new version is available

## Install

Download the latest [DMG from Releases](https://github.com/adammiribyan/peek/releases/latest), drag to Applications, and run:

```
xattr -cr /Applications/Peek.app
```

On first launch, click "Connect to Jira" to authorize via OAuth.

## Build from source

```
git clone https://github.com/adammiribyan/peek.git
cd peek
make run
```

Requires Swift 6.2+ and macOS 26. You'll need to set `PEEK_APP_TOKEN` and `PEEK_JIRA_SECRET` environment variables (or edit `Peek/Secrets.swift` directly — see `Secrets.swift.example`).

## Privacy

Peek sends ticket data to Anthropic (Claude) for summarization. No data is used for model training. You must grant explicit consent before any data leaves your machine, and you can revoke it at any time. See [PRIVACY.md](PRIVACY.md) for full details.

## License

MIT
