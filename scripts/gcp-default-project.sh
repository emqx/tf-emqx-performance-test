#!/usr/bin/env sh
# Emit the active gcloud project as JSON for the Terraform `external` data source:
# {"project":"<id>"}. Used when gcp.project is not set in the spec.
set -eu

project=$(gcloud config get-value project 2>/dev/null || true)

if [ -z "$project" ] || [ "$project" = "(unset)" ]; then
  echo "no default gcloud project found; set gcp.project in the spec or run: gcloud config set project <id>" >&2
  exit 1
fi

printf '{"project":"%s"}' "$project"
