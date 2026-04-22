# notch8-cloudflare-example

A minimal, runnable example of the Cloudflare-Free-tier + OpenTofu edge-protection pattern
Notch8 uses to keep multi-tenant [Hyku](https://hykucommons.org/) / [Hyrax](https://samvera.github.io/)
digital-repository platforms stable under AI-scraper traffic.

This repo is the public companion to the *"From Whack-a-Mole to Edge Protection"* talk at
the [Lyrasis AI Discussions WG Solutions Showcase](https://wiki.lyrasis.org/display/cmtygp/Solutions+Showcase+Series).
It is intentionally a **teaching example** — it mirrors the same patterns as the
in-house `notch8-ops` module (WAF, rate limit, bot, cache, opt-in DNS / custom hostnames)
without production-specific automation.

> [!NOTE]
> Written by the DevOps & Infrastructure team at [Notch8](https://www.notch8.com/).
> Released under the MIT license so you can copy, adapt, and share freely.

## What this shows

Cloudflare **free tier**–compatible rules, wired in one root module, aligned with
Notch8’s `terraform/cloudflare` layout:

1. **WAF** (`waf_rules.tf`) — allow-list (Site24x7, OAI-PMH, static paths, OAI, SAML
   metadata), block WordPress probes, managed challenge on `/catalog` (IIIF OCR
   search carve-out)
2. **Rate limiting** (`rate_limiting.tf`) — `/catalog`, colo + IP
3. **Bot Fight Mode** (`bot_management.tf`)
4. **Cache rules** (`cache_rules.tf`) — static assets, optional homepages, optional
   `cache_dynamic_pages` for Hyku-style paths
5. **DNS** (`dns_records.tf`) and **custom hostnames** (`custom_hostnames.tf`) — opt-in
   per zone, with data in `dns.tfvars` / `custom_hostnames.tfvars` under `envs/`

Workspace isolation, CI wrappers, and 1Password integration stay in the private ops
repo — this example is only the Terraform root module and env tfvars.

## Architecture

```
User / Bot → Cloudflare (free tier)                → Origin (load balancer)   → Application
            ├─ WAF Skip rules  (trusted bots)        CNAME / A record           Hyku / Hyrax
            ├─ WAF Block rules (known-bad probes)                               Solr · Postgres · Fedora
            ├─ Managed Challenge on /catalog
            ├─ Rate limit per colo + IP
            └─ Bot Fight Mode (behavioral)
```

Every request is filtered, challenged, or blocked at the edge before it consumes
origin CPU / memory / DB connections. Shared cluster resources stay stable because
one noisy tenant no longer degrades everyone else.

## Repo layout

```
.
├── providers.tf
├── variables.tf
├── waf_rules.tf
├── rate_limiting.tf
├── bot_management.tf
├── cache_rules.tf
├── dns_records.tf
├── custom_hostnames.tf
├── outputs.tf
└── envs/
    ├── example-account-1/
    │   ├── main.tfvars
    │   ├── dns.tfvars
    │   └── custom_hostnames.tfvars
    └── example-account-2/
        ├── main.tfvars
        ├── dns.tfvars
        └── custom_hostnames.tfvars
```

## Quick start

1. **Prerequisites**
   - [OpenTofu](https://opentofu.org/) ≥ 1.6 (or Terraform ≥ 1.6)
   - A Cloudflare account with at least one zone on the **Free** plan
   - An S3 bucket for state, or switch `providers.tf` to a local/other backend

2. **Create a scoped Cloudflare API token**

   Cloudflare Dashboard → Profile → API Tokens → *Create Token*, with (at least) these
   zone permissions for WAF + bot + cache:

   | Scope | Permission | Access |
   |-------|------------|--------|
   | Zone  | Zone            | Read |
   | Zone  | Zone WAF        | Edit |
   | Zone  | Zone Settings   | Edit |
   | Zone  | Bot Management  | Edit |

   If you use **managed DNS** or **custom hostnames**, add **DNS Edit** and **SSL and
   Certificates (Custom hostnames)** as required by your workflow.

3. **Copy and edit the example tfvars**

   ```bash
   cp -r envs/example-account-1 envs/my-account
   # Edit my-account/main.tfvars (and dns.tfvars / custom_hostnames.tfvars if needed)
   ```

4. **Apply** (load all three var-files so DNS and custom hostname defaults apply)

   ```bash
   export TF_VAR_cloudflare_api_token='your-api-token'
   tofu init
   tofu workspace new my-account
   VARFILES="-var-file=envs/my-account/main.tfvars -var-file=envs/my-account/dns.tfvars -var-file=envs/my-account/custom_hostnames.tfvars"
   tofu plan  $VARFILES
   tofu apply $VARFILES
   ```

## Gotchas we learned the hard way

These are the things that bit us in production. Don't relearn them:

1. **Allow-list legitimate bots explicitly.** Our first rollout broke OAI-PMH
   harvesting because the managed challenge rule caught harvesters as "bots" (which
   they are — just the ones we want). Lesson: every repository environment has a tail
   of *good* bots you must allow-list. See `waf_rules.tf`.

2. **Behavioral detection beats user-agent blocking.** We don't explicitly blocklist
   `GPTBot` / `ClaudeBot` / `CCBot` by user-agent, because the bad actors that matter
   already spoof UAs. Bot Fight Mode + a managed challenge on expensive endpoints
   catches behavior, not labels.

3. **Rate-limit per colo + IP, not just per IP.** Distributed scrapers rotate IPs
   aggressively. Adding `cf.colo.id` to the rate-limit key catches bursts at a
   single edge location before per-IP limits would trip.

4. **Match-and-block has sharp edges.** Early rules matched `xmlrpc.php` exactly — we
   missed `//xmlrpc.php` (double-slash variant) on the first pass. `contains` is
   safer than exact match for known-bad paths.

5. **Challenge endpoints can break background fetches.** If your app makes
   non-interactive fetches against a challenged path (e.g. IIIF OCR search endpoints
   inside Universal Viewer), carve them out explicitly. They can't solve a JS challenge.

6. **Cloudflare Free caps you at 10 cache rules per zone.** Not an issue in this
   minimal example, but plan for it if you expand.

7. **IaC doesn't save you from provider bugs.** The Cloudflare Terraform provider
   has had meaningful import bugs in recent major versions. Pin your version, read
   the changelog on upgrades, and always `plan` before `apply`.

## Why free tier

Our clients are libraries, archives, and universities — budget matters. Everything
in this example runs on Cloudflare's **Free** plan, which means adding edge
protection to a repository costs $0 in Cloudflare fees. The cost is our engineering
time to maintain the IaC — which is bounded, version-controlled, and shrinks over
time as the patterns stabilize.

If you need enterprise features (custom bot management, per-request logs pushed to
S3, WAF managed rulesets), Cloudflare's paid tiers layer on cleanly. This example
is the floor, not the ceiling.

## License

MIT — see [LICENSE](./LICENSE). Use it, fork it, rip out the parts you like.

## Contributing / questions

Issues and PRs welcome. If you're running Hyku, Hyrax, DSpace, Islandora, or any other
repository platform and hit something this example doesn't cover, open an issue — we'd
love to compare notes.

## Want to talk it through?

We're happy to share what's working for us. If your team would like a no-pressure
**30-minute review** of your own Cloudflare / edge setup, or if you just have a
question that doesn't fit in a GitHub issue, get in touch:

- Email April: **april@notch8.com**
- Contact Notch8: [notch8.com](https://www.notch8.com/) *(contact form)*
- Or open a GitHub issue on this repo — we'll see it

This is a community problem more than a vendor problem. If you came here from the
Lyrasis AI Discussions WG Solutions Showcase, thanks for stopping by — we'd love to
hear what's working (or not) on your end.

---

Maintained by [Notch8](https://www.notch8.com/) — DevOps & Infrastructure team.
