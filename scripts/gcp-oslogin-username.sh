#!/usr/bin/env sh
# Emit the active gcloud account's OS Login POSIX username as JSON for the
# Terraform `external` data source: {"username":"<name>"}.
# Arg 1 (optional): GCP project id, used as the quota/billing project.
set -eu

project="${1:-}"

if [ -n "$project" ]; then
  username=$(gcloud compute os-login describe-profile \
    --project "$project" --format='value(posixAccounts[0].username)')
else
  username=$(gcloud compute os-login describe-profile \
    --format='value(posixAccounts[0].username)')
fi

if [ -z "$username" ]; then
  echo "could not resolve OS Login username from gcloud profile" >&2
  exit 1
fi

printf '{"username":"%s"}' "$username"
