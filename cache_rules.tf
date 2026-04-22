# ── Cache Rules ─────────────────────────────────────────────────────
#
# Three tiers of caching, all available on Cloudflare Free:
#
#   1. Static assets   — /images/, /assets/, /downloads/, etc. (2h edge TTL)
#   2. Homepage         — exact "/" for listed tenants (1h edge TTL)
#   3. Dynamic pages    — /concern/*, /catalog, / zone-wide (30min/10min edge TTL)
#      Opt-in via cache_dynamic_pages = true in tfvars.
#
# Dynamic page caching uses the _hyku_session cookie to exclude authenticated HTML.
# Static asset rules do not check cookies.
#
# Cloudflare Free: 10 cache rules per zone (shared across these rule blocks per zone).

locals {
  default_cache_paths = ["/images/", "/downloads/", "/system/", "/assets/", "/pdf.js/", "/uploads/"]

  cache_expressions = {
    for k, v in var.zones : k => join(" or ",
      [for p in concat(local.default_cache_paths, v.extra_cache_paths) :
        "(http.host contains \"${v.host_filter}\" and starts_with(http.request.uri.path, \"${p}\"))"
      ]
    )
  }

  # Per-hostname static rules: `extra_cache_hosts` plus `extra_hosts` (de-duplicated)
  extra_cache_host_expressions = {
    for k, v in var.zones : k => {
      for host in distinct(concat(v.extra_cache_hosts, v.extra_hosts)) : host => join(" or ",
        [for p in concat(local.default_cache_paths, v.extra_cache_paths) :
          "(http.host contains \"${host}\" and starts_with(http.request.uri.path, \"${p}\"))"
        ]
      )
    }
  }

  homepage_cache_expressions = {
    for k, v in var.zones : k => join(" or ",
      [for host in v.homepage_cache_hosts :
        "(http.host eq \"${host}\" and http.request.uri.path eq \"/\")"
      ]
    ) if length(v.homepage_cache_hosts) > 0
  }
}

resource "cloudflare_ruleset" "cache_rules" {
  for_each = { for k, v in var.zones : k => v if v.cache_rules }

  zone_id = each.value.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_cache_settings"

  rules {
    action      = "set_cache_settings"
    expression  = local.cache_expressions[each.key]
    description = "Cache static assets for ${each.value.host_filter}"
    enabled     = true

    action_parameters {
      cache = true
      edge_ttl {
        mode    = "override_origin"
        default = each.value.cache_edge_ttl_hours * 3600
      }
      browser_ttl {
        mode    = "override_origin"
        default = each.value.cache_browser_ttl_min * 60
      }
    }
  }

  dynamic "rules" {
    for_each = local.extra_cache_host_expressions[each.key]
    content {
      action      = "set_cache_settings"
      expression  = rules.value
      description = "Cache static assets for ${rules.key}"
      enabled     = true

      action_parameters {
        cache = true
        edge_ttl {
          mode    = "override_origin"
          default = each.value.cache_edge_ttl_hours * 3600
        }
        browser_ttl {
          mode    = "override_origin"
          default = each.value.cache_browser_ttl_min * 60
        }
      }
    }
  }

  dynamic "rules" {
    for_each = (
      contains(keys(local.homepage_cache_expressions), each.key) &&
      !each.value.cache_dynamic_pages
    ) ? [1] : []
    content {
      action      = "set_cache_settings"
      expression  = "(${local.homepage_cache_expressions[each.key]}) and not (http.cookie contains \"_hyku_session\")"
      description = "Cache tenant homepages (listed hosts)"
      enabled     = true

      action_parameters {
        cache = true
        edge_ttl {
          mode    = "override_origin"
          default = each.value.homepage_cache_edge_ttl
        }
        browser_ttl {
          mode    = "override_origin"
          default = each.value.homepage_cache_browser_ttl
        }
      }
    }
  }

  dynamic "rules" {
    for_each = each.value.cache_dynamic_pages ? [1] : []
    content {
      action      = "set_cache_settings"
      expression  = "http.request.uri.path eq \"/\" and not (http.cookie contains \"_hyku_session\")"
      description = "Cache all tenant homepages zone-wide"
      enabled     = true

      action_parameters {
        cache = true
        edge_ttl {
          mode    = "override_origin"
          default = each.value.homepage_cache_edge_ttl
        }
        browser_ttl {
          mode    = "override_origin"
          default = each.value.homepage_cache_browser_ttl
        }
      }
    }
  }

  dynamic "rules" {
    for_each = each.value.cache_dynamic_pages ? [1] : []
    content {
      action      = "set_cache_settings"
      expression  = "(starts_with(http.request.uri.path, \"/concern/\") or starts_with(http.request.uri.path, \"/collections/\")) and not (http.request.uri.path contains \"edit\") and not (http.cookie contains \"_hyku_session\")"
      description = "Cache work + collection pages (30min)"
      enabled     = true

      action_parameters {
        cache = true
        edge_ttl {
          mode    = "override_origin"
          default = each.value.dynamic_cache_edge_ttl
        }
        browser_ttl {
          mode    = "override_origin"
          default = each.value.dynamic_cache_browser_ttl
        }
      }
    }
  }

  dynamic "rules" {
    for_each = each.value.cache_dynamic_pages ? [1] : []
    content {
      action      = "set_cache_settings"
      expression  = "(http.request.uri.path eq \"/catalog\" or http.request.uri.path eq \"/catalog.html\" or starts_with(http.request.uri.path, \"/catalog/facet/\") or http.request.uri.path eq \"/catalog.atom\" or http.request.uri.path eq \"/catalog.rss\") and not (http.cookie contains \"_hyku_session\")"
      description = "Cache catalog + facets + feeds (10min)"
      enabled     = true

      action_parameters {
        cache = true
        edge_ttl {
          mode    = "override_origin"
          default = each.value.catalog_cache_edge_ttl
        }
        browser_ttl {
          mode    = "override_origin"
          default = each.value.catalog_cache_browser_ttl
        }
      }
    }
  }
}
