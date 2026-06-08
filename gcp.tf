###############################################################################
# GCP identity / SSH access via OS Login
#
# The org enforces constraints/compute.requireOsLogin, so instances cannot
# disable OS Login and metadata ssh-keys are ignored.
#
# The OS Login API only lets a principal register an SSH key on its OWN profile,
# so we register the generated key to the identity running Terraform (not to a
# service account), grant that identity osAdminLogin (login + passwordless sudo
# for Ansible `become`), and have Ansible connect as its OS Login POSIX
# username. That username is assigned by OS Login and is org-dependent, so we
# read it back from the profile rather than guessing.
#
# A dedicated service account is still attached to the instances as their own
# identity (so EMQX can reach GCP APIs like Pub/Sub later) — it is not used for
# SSH.
###############################################################################

# Detect the active gcloud project when gcp.project is not set in the spec.
data "external" "gcp_project" {
  count   = local.cloud_is_gcp && local.gcp_project_spec == "" ? 1 : 0
  program = ["sh", "${path.module}/scripts/gcp-default-project.sh"]
}

data "google_client_openid_userinfo" "me" {
  count = local.cloud_is_gcp ? 1 : 0
}

resource "google_service_account" "gce" {
  count        = local.cloud_is_gcp ? 1 : 0
  account_id   = "${local.prefix}-gce"
  display_name = "GCE perftest (${local.prefix})"
}

# Let the Terraform caller SSH in (login + sudo) via OS Login.
resource "google_project_iam_member" "oslogin" {
  count   = local.cloud_is_gcp ? 1 : 0
  project = local.gcp_project
  role    = "roles/compute.osAdminLogin"
  member  = "user:${data.google_client_openid_userinfo.me[0].email}"
}

# Register the generated key on the caller's own OS Login profile.
resource "google_os_login_ssh_public_key" "me" {
  count = local.cloud_is_gcp ? 1 : 0
  user  = data.google_client_openid_userinfo.me[0].email
  key   = tls_private_key.pk.public_key_openssh
}

# Resolve the caller's OS Login POSIX username from their profile (the username
# is org-dependent, so we read it rather than derive it). Runs at apply time,
# after the key is registered. Skipped when var.gcp_oslogin_user is provided
# (avoids the gcloud dependency).
data "external" "oslogin_username" {
  count      = local.cloud_is_gcp && var.gcp_oslogin_user == "" ? 1 : 0
  program    = ["sh", "${path.module}/scripts/gcp-oslogin-username.sh", local.gcp_project]
  depends_on = [google_os_login_ssh_public_key.me]
}

locals {
  gcp_service_account_email = local.cloud_is_gcp ? google_service_account.gce[0].email : ""
  gcp_oslogin_user = local.cloud_is_gcp ? (
    var.gcp_oslogin_user != "" ? var.gcp_oslogin_user : one(data.external.oslogin_username[*].result.username)
  ) : ""
}
