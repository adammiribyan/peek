# Privacy Policy

*Last updated: March 28, 2026*

Peek is a macOS menu bar app for viewing Jira tickets with AI-powered summaries. This policy explains what data is collected, how it is used, and where it is sent.

## Jira Data

Peek connects to your Jira Cloud instance using your credentials (OAuth tokens or API token + email). It accesses ticket metadata: key, title, status, assignee, reporter, priority, type, project, description, comments, linked issues, and pull request links.

Jira data is displayed locally in the app. Credentials are stored in the macOS Keychain. Your Jira domain is stored in app preferences.

## AI Processing

Peek sends ticket data (title, description, comments, metadata) to a third-party AI provider for summarization and risk assessment. The active provider is either:

- **Anthropic** (Claude) — [anthropic.com/privacy](https://www.anthropic.com/privacy)
- **DeepSeek** (via Baseten) — [baseten.co/privacy](https://www.baseten.co/privacy)

Data is processed in transit and is not retained by the AI provider beyond the request. No data is used for model training. You must grant explicit consent before any data is sent to AI providers, and you can revoke consent at any time in Settings.

When using the DeepSeek backend, requests are routed through a Cloudflare Worker proxy. The proxy forwards requests without storing any data.

## Analytics

Peek uses [PostHog](https://posthog.com/privacy) for product analytics. Events tracked include: app launches, ticket views, search actions, settings changes, and feature usage. Your Jira email is used as an identifier for analytics. No ticket content is sent to PostHog — only event names and metadata (ticket keys, statuses, timing).

## Local Storage

- **Keychain**: OAuth tokens and API keys (encrypted by macOS)
- **Preferences**: Jira domain, email, search bar position, AI consent flag
- **Cache**: AI-generated summaries and risk assessments stored in the app's Application Support directory. Cleared automatically when tickets are updated in Jira.

## Update Checks

Peek checks GitHub Releases for updates. No user data is sent — only the latest release version is retrieved.

## Data Sharing

Data is shared with: your Jira Cloud instance (Atlassian), the active AI provider (Anthropic or Baseten), PostHog (analytics), and GitHub (update checks). No data is sold to third parties.

## Your Controls

- Revoke AI consent in Settings to stop sending ticket data to AI providers
- To delete all local data: remove the app from Applications (deletes container and preferences). Keychain items can be removed via Keychain Access.app.

## Contact

For privacy inquiries: [github.com/adammiribyan/peek/issues](https://github.com/adammiribyan/peek/issues)
