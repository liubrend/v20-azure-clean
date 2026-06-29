#!/usr/bin/env bash
# Shared regexes for fail-closed policy checks.

# Obvious hardcoded secret assignments. This is intentionally conservative:
# it catches literal credentials while avoiding broad matches on variable names.
SECRET_RE='(api[_-]?key|secret|password|passwd|token)[[:space:]]*[:=][[:space:]]*['"'"'"][^'"'"'"]{8,}['"'"'"]'

# Trading guardrail used by older templates: market orders are forbidden where
# limit-only execution is required.
MARKET_ORDER_RE='(order_type|type)[[:space:]]*[:=][[:space:]]*['"'"'"]?market['"'"'"]?'
