# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
make build          # Debug build
make run            # Build and run
make app            # Release .app bundle
make dmg            # Release DMG for distribution
make clean          # Clean build artifacts
```

No Xcode project — the Makefile constructs the .app bundle manually using PlistBuddy and ad-hoc codesign.

## Architecture

Peek is a macOS menu bar app (no dock icon) that provides instant Jira ticket lookup with AI summaries. Built with SwiftUI hosted inside AppKit NSPanels.

### Core Flow

**AppDelegate** → **PanelManager** → **FloatingPanel** (NSPanel) → **TicketPanelView** (SwiftUI)

Each `Cmd+Shift+J` creates a new FloatingPanel containing a TicketPanelView that has two phases:
1. **Search phase** — compact 360px bar with project autocomplete
2. **Card phase** — 420px ticket card with summary, PRs, linked issues, risk dot

The panel **morphs in-place** from search to card via `NSAnimationContext` frame animation. The SwiftUI content switches phase simultaneously.

### Panel Lifecycle

- `PanelManager.showNewSearch()` → creates panel, sets `dismissesOnResignKey = true`
- User submits → `TicketPanelView` fetches issue, calls `onMorphToCard(ticketKey)`
- `PanelManager.morphToCard()` → checks for duplicate (brings existing to front), animates frame, sets `dismissesOnResignKey = false`
- `PanelManager.openTicketDirectly(key:)` → for linked ticket clicks, creates panel with `autoSubmitKey`

Panels tracked in `panels: [UUID: FloatingPanel]` and `panelTicketKeys: [UUID: String]` for dedup.

### FloatingPanel

NSPanel subclass. Always `.borderless` — never `.titled` (which causes a visible separator line on macOS 26). No resize. `hasShadow = false` to avoid window frame outline artifacts. Uses `.glassEffect()` in SwiftUI for the visual treatment.

### Dual LLM Backend

`SummaryService` supports two backends behind the `baseten_inference` PostHog feature flag:
- **Anthropic** (default) — Claude Sonnet 4.6, SSE streaming via `content_block_delta` events
- **Baseten** — DeepSeek V3.1 via Cloudflare Worker proxy (`worker/`), OpenAI-compatible SSE

Both `streamSummary()` and `assessRisk()` dispatch to the active backend. Risk assessment is non-streaming, returns JSON `{"level": "green|yellow|red", "reason": "..."}`.

### Credential Storage

Uses `/usr/bin/security` CLI to read/write macOS Keychain — avoids code-signing entitlement issues with ad-hoc SPM builds. Service ID: `am.adam.peek`. Jira domain and email stored in UserDefaults.

### Summary Caching

`SummaryCacheService` stores summaries + risk at `~/Library/Application Support/am.adam.peek/summary_cache.json`. Cache key: ticket key. Invalidation: Jira's `updated` timestamp. Behind `summary_cache` feature flag.

### Markdown Rendering

`MarkdownBlockView` parses markdown into blocks (headings, bullets, numbered lists, paragraphs) and renders each as SwiftUI views. Inline formatting via `AttributedString(markdown:)`. Auto-detects Jira ticket keys (`[A-Z]+-\d+`) and renders them as clickable `peek://` links that open tickets in new panels.

## Feature Flags (PostHog)

- `baseten_inference` — use DeepSeek instead of Claude
- `linked_issues` — show Jira issue links on cards
- `summary_cache` — enable summary caching

Flags reload on each card open via `PostHogSDK.shared.reloadFeatureFlags()`.

## Key Files

| File | Purpose |
|------|---------|
| `Peek/Panels/PanelManager.swift` | Panel lifecycle, morph animation, dedup, position saving |
| `Peek/Views/TicketPanelView.swift` | Search bar + card container, project autocomplete, submit flow |
| `Peek/Services/SummaryService.swift` | LLM integration (Anthropic + Baseten), streaming, risk assessment |
| `Peek/Services/JiraService.swift` | Jira REST API v3, projects, dev-status PRs |
| `Peek/Views/TicketCardView.swift` | Card layout, metadata badges, PRs, linked issues, copy link |
| `Peek/Views/MarkdownBlockView.swift` | Block-level markdown renderer with ticket key linkification |

## Gotchas

- **Never use `.titled` style mask** on FloatingPanel — causes visible separator line on macOS 26
- **`hasShadow = false`** required to prevent window frame outline on borderless panels
- **2px padding** around `.glassEffect()` prevents corner clipping artifacts
- **Search bar position** saved as top edge Y (`searchBarTopY`) not origin Y, to prevent drift
- **`focusNumber(seed:)`** uses double-deferred dispatch to avoid TextField select-all-on-focus overwrite
- **Keychain** uses `/usr/bin/security` subprocess, not Security framework directly — code-signing workaround
- **Risk assessment** silently returns green on any failure — never blocks the UI
- **`max_tokens: 1024`** for summaries — 512 caused truncation on complex tickets
