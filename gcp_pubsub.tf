###############################################################################
# GCP Pub/Sub topic + a dedicated publisher service account for the EMQX bridge.
#
# EMQX's GCP Pub/Sub connector authenticates with a service-account JSON key
# (not the instance identity), so we mint a key here and hand it to the EMQX
# integration script via Ansible. Enable with `gcp.pubsub.enabled: true`.
###############################################################################

locals {
  pubsub_enabled    = local.cloud_is_gcp && try(local.spec.gcp.pubsub.enabled, false)
  pubsub_topic_name = try(local.spec.gcp.pubsub.topic, "${local.prefix}-bench")
  # MQTT topic filter whose messages get forwarded to Pub/Sub.
  pubsub_rule_sql = try(local.spec.gcp.pubsub.rule_sql, "SELECT * FROM \"bench/#\"")
}

resource "google_pubsub_topic" "bench" {
  count = local.pubsub_enabled ? 1 : 0
  name  = local.pubsub_topic_name
}

resource "google_service_account" "pubsub" {
  count        = local.pubsub_enabled ? 1 : 0
  account_id   = "${local.prefix}-pubsub"
  display_name = "EMQX Pub/Sub bridge (${local.prefix})"
}

resource "google_pubsub_topic_iam_member" "publisher" {
  count  = local.pubsub_enabled ? 1 : 0
  topic  = google_pubsub_topic.bench[0].name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.pubsub[0].email}"
}

# EMQX's connector healthcheck does a topics.get, which roles/pubsub.publisher
# (publish-only) does not grant — without this the bridge reports
# "Permission denied for topic" and stays disconnected.
resource "google_pubsub_topic_iam_member" "viewer" {
  count  = local.pubsub_enabled ? 1 : 0
  topic  = google_pubsub_topic.bench[0].name
  role   = "roles/pubsub.viewer"
  member = "serviceAccount:${google_service_account.pubsub[0].email}"
}

resource "google_service_account_key" "pubsub" {
  count              = local.pubsub_enabled ? 1 : 0
  service_account_id = google_service_account.pubsub[0].name
}

locals {
  # Decoded JSON key the EMQX connector expects as `service_account_json`.
  pubsub_sa_key_json = local.pubsub_enabled ? base64decode(google_service_account_key.pubsub[0].private_key) : ""
}
