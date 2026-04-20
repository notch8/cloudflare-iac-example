# ── Provider + backend configuration ────────────────────────────────
#
# This example uses an S3 backend for state — swap it out for whatever
# your team uses (local, GCS, HTTP backend, etc.). The important thing
# is that state is stored somewhere durable and shared across the team.
#
# The Cloudflare API token is supplied via the TF_VAR_cloudflare_api_token
# environment variable. At Notch8 we fetch it from 1Password at apply time
# so nothing sensitive ever lands in tfvars or git.

terraform {
  required_version = ">= 1.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # Replace with your own state backend.
  # backend "s3" {
  #   bucket = "your-opentofu-state-bucket"
  #   key    = "cloudflare-example/terraform.tfstate"
  #   region = "us-west-2"
  # }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
