# ── WAF Custom Rules ────────────────────────────────────────────────
#
# Creates a custom ruleset per zone with four groups of rules:
#
#   1. Skip rules (bots)  — allow-list legitimate bots (Site24x7, OAI-PMH)
#                          so monitoring and harvesting are never challenged
#   2. Skip rules (paths) — static asset paths, OAI, SAML metadata, feeds
#                          (never challenged or rate-limited at the WAF)
#   3. Block rules        — drop WordPress probe traffic before origin
#   4. Managed challenge  — challenge /catalog so real browsers pass but
#                          headless scrapers fail (IIIF OCR search is carved out)
#
# Rule order matters — Cloudflare evaluates rules top-to-bottom, so the skip
# rules MUST come first. If a managed challenge is evaluated before the
# allow-list, your OAI-PMH harvesters and feed readers will break.

locals {
  # Default static paths to skip (plus `extra_skip_paths` per zone in variables).
  # These are merged with OAI-PMH endpoint, SAML metadata wildcard, and feed paths
  # in `skip_expressions` — paths that should not be challenged or WAF-limited
  # the same way as dynamic HTML. Add more in `extra_skip_paths` as you find them.
  default_skip_paths = ["/images/", "/downloads/", "/system/", "/assets/", "/pdf.js/"]

  # Hostnames that receive the /catalog managed challenge: apex + extra_hosts +
  # extra_cache_hosts, de-duplicated. See the Rule 4 comment below.
  waf_catalog_hosts = {
    for k, v in var.zones : k => distinct(concat(
      [v.host_filter],
      v.extra_hosts,
      v.extra_cache_hosts,
    ))
  }

  # One expression per zone: (static prefixes) OR (OAI) OR (SAML) OR (feeds)
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

  # ── Rule 1: Skip for monitoring + harvesting user-agents ──────────
  # Site24x7 is our uptime monitor; OAI-PMH is the standard library
  # metadata harvesting protocol. Both look like "bots" to a naive WAF
  # because they are — just the ones we want.
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

  # ── Rule 2: Skip for static assets, OAI, SAML metadata, and feeds ──
  # The skip rules above (Rule 1) and this path-based skip must run before
  # any challenge or block so feeds and OAI keep working.
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

  # ── Rule 3: Block WordPress probes ─────────────────────────────────
  # xmlrpc.php is a legacy attack surface — block globally. wp-login,
  # wp-admin, wp-cron are blocked on *tenant* hosts but allowed on the
  # bare zone domain (e.g. a marketing WordPress site on the apex).
  #
  # Note "contains" (not "eq") on xmlrpc.php — it catches both
  # "/xmlrpc.php" and the double-slash variant "//xmlrpc.php" that some
  # scanners probe.
  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"xmlrpc.php\") or ((http.request.uri.path contains \"/wp-login.php\" or http.request.uri.path contains \"/wp-cron.php\" or http.request.uri.path contains \"/wp-admin\") and not (http.host eq \"${each.value.host_filter}\"))"
    description = "Block xmlrpc globally + WordPress probes on tenant hosts"
    enabled     = true
  }

  # ── Rule 4: Managed challenge on /catalog ──────────────────────────
  # Real browsers solve the JS challenge transparently; headless scrapers
  # cannot. This is the single highest-leverage rule for expensive catalog
  # traffic — pagination and facets.
  #
  # Rules 1–2 ensure Site24x7, OAI-PMH, and quiet paths are not caught. We
  # also exclude /catalog/.../iiif_search: UV makes background fetches that
  # cannot complete an interactive challenge.
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
