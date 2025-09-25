resource "google_service_account" "bastion" {
  account_id   = "${var.environment}-bastion-sa"
  display_name = "Bastion Host Service Account"
}

resource "google_project_iam_member" "bastion_gke_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.bastion.email}"
}

resource "google_compute_instance" "bastion" {
  name         = "${var.environment}-bastion"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["iap-access", "bastion"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.private.name
  }

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y kubectl google-cloud-sdk-gke-gcloud-auth-plugin curl wget unzip git

    # Install helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Install gcloud auth plugin for kubectl
    apt-get install -y google-cloud-cli-gke-gcloud-auth-plugin

    # Create kubectl config directory
    mkdir -p /home/debian/.kube
    chown -R debian:debian /home/debian/.kube
  EOT

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}

resource "google_iap_tunnel_instance_iam_member" "bastion_users" {
  for_each = toset(var.allowed_iap_users)
  instance = google_compute_instance.bastion.name
  zone     = var.zone
  role     = "roles/iap.tunnelResourceAccessor"
  member   = each.value
}

output "bastion_ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}