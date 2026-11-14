---
name: incidentio-dedupes-sentry-issue
description: Treasury fatal Sentry events page via incident.io deduped on the Sentry issue id — repeat fatals during an outage join the open alert, they don't re-page
metadata:
  type: reference
---
Sentry rule "Treasury Fatal Exceptions to Incident.io" (1138388) fires on level == fatal (any event, 30-min throttle); "Treasury to Slack" (1138387, #bank-exceptions) on level >= error. incident.io alert source "Sentry Banking Alerts" uses `deduplication_key` = Sentry issue id, so while the alert is firing, further fatals of the same issue don't page. Evidence: TREASURY-6GB had 40 events but 6 incident.io alerts (2026-09-13 → 10-23). So "1 page per outage" needs no extra Datadog monitor; ErrorTracker.warning (level 30) neither pages nor Slacks. Learned on BANK-2398, where I wrongly claimed hourly failures would page hourly.
