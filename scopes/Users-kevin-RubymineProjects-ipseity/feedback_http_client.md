---
name: HTTP calls use Faraday, not Net::HTTP or HTTParty
description: In this Ipseity codebase, all new HTTP client code must use Faraday; Net::HTTP and HTTParty are legacy and actively being migrated away from
type: feedback
originSessionId: 3671a678-85e7-40db-a1f7-1a2a37316e45
---
For any new HTTP client code in the Ipseity codebase, use **Faraday** — not `Net::HTTP`, not `HTTParty`.

**Why:** Team convention established in Slack (https://angellist.slack.com/archives/GA7RA36N6/p1722545607401679). The repo is actively migrating legacy `Net::HTTP` / `HTTParty` callsites to Faraday, so new code using the legacy libraries creates more migration work. A reviewer flagged this on a PR where the script used `Net::HTTP.get_response`.

**How to apply:** When writing any HTTP request in Ipseity (new service, one-off script, integration client, etc.), reach for Faraday. Do not rely on the fact that some legacy files still use `Net::HTTP` or `HTTParty` — those are debt. If you encounter them while working in-area, a Faraday migration is welcome per the reviewer's comment, but it's not required unless the task is specifically about that file.

**Reference pattern (from `lib/flowdash/client.rb:332`):**
```ruby
Faraday.new(API_BASE_URL) do |f|
  f.request :authorization, :Bearer, API_KEY
  f.request :json
  f.response :json
  f.headers['User-Agent'] = USER_AGENT
  f.request :retry, {
    max: 2,
    interval: 0.05,
    backoff_factor: 2,
    exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed, EOFError],
  }
end
```

For errors: `rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::ParsingError, Faraday::Error`. For HTTP status: `response.status`. For parsed body: `response.body` (already deserialized if `f.response :json`).
