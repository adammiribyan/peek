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

Hit **⌘⇧J** from anywhere, type a ticket number, and get an AI-generated summary in a floating card — without switching windows or opening a browser.

Open multiple tickets. Click linked issues to follow the thread. Every ticket gets a risk assessment. It just works.

## Install

Download the latest [DMG from Releases](https://github.com/adammiribyan/peek/releases/latest), drag to Applications, and run:

```
xattr -cr /Applications/Peek.app
```

On first launch, enter your Jira domain, email, and [API token](https://id.atlassian.com/manage-profile/security/api-tokens).

## Build from source

```
git clone https://github.com/adammiribyan/peek.git
cd peek
make run
```

Requires Swift 6.2+ and macOS 26.

## License

MIT
