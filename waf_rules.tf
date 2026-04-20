# ── WAF Custom Rules ────────────────────────────────────────────────
#
# Creates a custom ruleset per zone with three kinds of rules:
#
#   1. Skip rules  — allow-list legitimate bots (Site24x7, OAI-PMH)
#                    and quiet paths (RSS, Atom, OAI endpoint)
#   2. Block rules — drop WordPress probe traffic before origin
#   3. Managed Challenge — challenge /catalog so real browsers pass
#                    but headless scrapers fail
#
# Rule order matters — Cloudflare evaluates rules top-to-bottom, so
# the skip rules MUST come first. If a managed challenge rule is
# evaluated before the allow-list, your OAI-PMH harvesters will break.

locals {
  # Paths that should never be challenged or rate-limited:
  # - /catalog/oai  — OAI-PMH harvesting endpoint
  # - /catalog.atom, /catalog.rss — feeds
  # Add more here as you discover them (SAML metadata, IIIF search, etc.)
  skip_paths_expression = join(" or ", [
    "(http.request.uri.path contains \"/catalog/oai\")",
    "(http.request.uri.path eq \"/catalog.atom\")",
    "(http.request.uri.path eq \"/catalog.rss\")",
  ])
}

resource "cloudflare_ruleset" "waf_custom_rules" {
  for_each = { for k, v in var.zones : k => v if v.waf_custom_rules_enabled }

  zone_id = each.value.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  # ── Rule 1: Skip for monitoring + harvesting user-agents ───────────
  # Site24x7 is our uptime monitor; OAI-PMH is the standard library
  # metadata harvesting protocol. Both look like "bots" to a naive
  # WAF because they are — just the ones we want.
  dynamic "rules" {
    for_each = each.value.site24x7_bot_skip ? [1] : []
    content {
      action      = "skip"
      expression  = "(http.user_agent contains \"Site24x7\" or http.user_agent contains \"OAI-PMH\")"
      description = "Skip WAF for Site24x7 and OAI-PMH agents"
      enabled     = true
      action_parameters {
        ruleset  = "current"
        phases   = ["http_ratelimit", "http_request_firewall_managed", "http_request_sbfm"]
        products = ["bic", "hot", "rateLimit", "securityLevel", "uaBlock", "waf", "zoneLockdown"]
      }
      logging {
        enabled = true
      }
    }
  }

  # ── Rule 2: Skip for quiet paths (feeds, OAI endpoint) ─────────────
  rules {
    action      = "skip"
    expression  = local.skip_paths_expression
    description = "Skip WAF for OAI endpoint and feed paths"
    enabled     = true
    action_parameters {
      ruleset  = "current"
      phases   = ["http_ratelimit", "http_request_firewall_managed", "http_request_sbfm"]
      products = ["bic", "hot", "rateLimit", "securityLevel", "uaBlock", "waf", "zoneLockdown"]
    }
    logging {
      enabled = true
    }
  }

  # ── Rule 3: Block WordPress probes ─────────────────────────────────
  # xmlrpc.php is a legacy attack surface — block globally.
  # wp-login / wp-admin / wp-cron are blocked on *tenant* hosts but
  # allowed on the bare zone domain (in case you actually run a
  # WordPress marketing site there).
  #
  # Note "contains" (not "eq") on xmlrpc.php — it catches both
  # "/xmlrpc.php" and the double-slash variant "//xmlrpc.php"
  # that some scanners probe.
  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"xmlrpc.php\") or ((http.request.uri.path contains \"/wp-login.php\" or http.request.uri.path contains \"/wp-cron.php\" or http.request.uri.path contains \"/wp-admin\") and not (http.host eq \"${each.value.host_filter}\"))"
    description = "Block xmlrpc globally + WordPress probes on tenant hosts"
    enabled     = true
  }

  # ── Rule 4: Managed Challenge on /catalog ──────────────────────────
  # Real browsers solve the JS challenge transparently; headless
  # scrapers cannot. This is the single highest-leverage rule in
  # the whole ruleset — /catalog is the endpoint scrapers love
  # because it walks your entire corpus via pagination and facets.
  #
  # The skip rules above ensure Site24x7, OAI-PMH, and feeds aren't
  # caught by this challenge.
  rules {
    action = "managed_challenge"
    expression = join(" or ",
      [for host in concat([each.value.host_filter], each.value.extra_hosts) :
        "(http.host contains \"${host}\" and http.request.uri.path contains \"/catalog\")"
      ]
    )
    description = "Challenge /catalog requests to defeat headless scrapers"
    enabled     = true
  }
}
