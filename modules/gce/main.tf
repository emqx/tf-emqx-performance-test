terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

data "google_compute_image" "image" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_instance" "instance" {
  # GCE instance names must match [a-z]([-a-z0-9]*[a-z0-9])? — no underscores.
  name         = replace(var.instance_name, "_", "-")
  machine_type = var.instance_type
  zone         = "${var.region}-${var.zone}"
  tags         = [var.network_tag]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.image.self_link
      size  = var.root_volume_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = var.subnetwork
    # Empty access_config block assigns an ephemeral external IP.
    access_config {}
  }

  # SSH is handled via OS Login (enforced org-wide), not metadata ssh-keys.
  # The attached service account's OS Login profile carries the key, and
  # Ansible logs in as its POSIX username (var.remote_user = sa_<unique_id>).
  metadata_startup_script = templatefile("${path.module}/templates/startup_script.tpl",
    {
      extra    = var.extra_user_data
      hostname = var.hostname
      # Data volumes are deferred for the GCP MVP.
      volumes = []
      certs   = var.certs
  })

  service_account {
    email = var.service_account_email
    # cloud-platform scope lets EMQX reach managed services (e.g. Pub/Sub).
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true
}

resource "google_dns_record_set" "dns" {
  name         = "${var.hostname}."
  type         = "A"
  ttl          = 30
  managed_zone = var.dns_zone_name
  rrdatas      = [google_compute_instance.instance.network_interface[0].network_ip]
}
