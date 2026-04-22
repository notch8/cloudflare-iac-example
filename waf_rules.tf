# ════════════════════════════════════════════════════════════════════════════
#
#   NOTCH8   ·   OpenTofu   ·   Cloudflare
#
#   WAF — custom rulesets
#   Skip (bots + paths) · block probes · managed challenge on /catalog
#
# ════════════════════════════════════════════════════════════════════════════
#
#   Four groups per zone:
#
#     1. Skip — user-agents (Site24x7, OAI-PMH)
#     2. Skip — paths (static, OAI, SAML, feeds)
#     3. Block — WordPress / xmlrpc probes
#     4. Challenge — /catalog (IIIF OCR search excluded)
#
#   Order is non-negotiable: Cloudflare evaluates top-to-bottom. Skips must run
#   before challenge, or OAI-PMH and feeds break.
#

locals {
  # Static path prefixes + per-zone `extra_skip_paths`; combined with OAI,
  # SAML wildcard, and Atom/RSS in `skip_expressions`.
  default_skip_paths = ["/images/", "/downloads/", "/system/", "/assets/", "/pdf.js/"]

  # Apex + `extra_hosts` + `extra_cache_hosts` (distinct) — who gets the
  # /catalog managed challenge.
  waf_catalog_hosts = {
    for k, v in var.zones : k => distinct(concat(
      [v.host_filter],
      v.extra_hosts,
      v.extra_cache_hosts,
    ))
  }

  # (static OR …) per zone
  skip_expressions = {
    for k, v in var.zones : k => join(" or ",
      concat(
        [for p in concat(local.default_skip_paths, v.extra_skip_paths) :
          "(starts_with(http.request.uri.path, \"${p}\"))"
        ],
        [
          "(http.request.uri.path contains \"/catalog/oai\")",
          "(http.request.uri.path wildcard r\"/users/auth/saml/*/metadata\")",
          "(http.request.uri.path eq \"/catalog.atom\")",
          "(http.request.uri.path eq \"/catalog.rss\")"
        ]
      )
    )
  }
}

resource "cloudflare_ruleset" "waf_custom_rules" {
  for_each = { for k, v in var.zones : k => v if v.waf_custom_rules_enabled }

  zone_id = each.value.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  # --------------------------------------------------------------------------
  #  Rule 1 — Skip: monitoring & harvesting user-agents
  # --------------------------------------------------------------------------
  #  Site24x7 = uptime; OAI-PMH = library metadata protocol. Both read as
  #  "bots" to a naive WAF — we want them through.
  #
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

  # --------------------------------------------------------------------------
  #  Rule 2 — Skip: static assets, OAI, SAML metadata, feeds
  # --------------------------------------------------------------------------
  #  Must precede any challenge or block so integrations and feeds keep working.
  #
  rules {
    action      = "skip"
    expression  = local.skip_expressions[each.key]
    description = "Skip WAF for static paths, OAI, and SAML metadata"
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

  # --------------------------------------------------------------------------
  #  Rule 3 — Block: WordPress probes
  # --------------------------------------------------------------------------
  #  xmlrpc.php: block everywhere. wp-* : block on tenant hosts, allow on apex
  #  if you run a marketing WP site on the bare zone name.
  #
  #  Use `contains` on xmlrpc — catches `/xmlrpc.php` and `//xmlrpc.php` probes.
  #
  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"xmlrpc.php\") or ((http.request.uri.path contains \"/wp-login.php\" or http.request.uri.path contains \"/wp-cron.php\" or http.request.uri.path contains \"/wp-admin\") and not (http.host eq \"${each.value.host_filter}\"))"
    description = "Block xmlrpc globally + WordPress probes on tenant hosts"
    enabled     = true
  }

  # --------------------------------------------------------------------------
  #  Rule 4 — Managed challenge: /catalog
  # --------------------------------------------------------------------------
  #  Browsers pass; headless scrapers do not. High leverage on Solr-heavy traffic.
  #
  #  Rules 1–2 keep harvesters and feeds out. `/…/iiif_search` is excluded — UV
  #  issues background fetches that cannot complete an interactive challenge.
  #
  rules {
    action = "managed_challenge"
    expression = join(" or ",
      [for host in local.waf_catalog_hosts[each.key] :
        "(http.host contains \"${host}\" and http.request.uri.path contains \"/catalog\" and not (starts_with(http.request.uri.path, \"/catalog/\") and ends_with(http.request.uri.path, \"/iiif_search\")))"
      ]
    )
    description = "Challenge catalog requests except IIIF OCR search endpoint"
    enabled     = true
  }
}
