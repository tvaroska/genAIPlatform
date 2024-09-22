# Provider configuration
provider "google" {
  project = var.project
  region  = "us-central1"
}

data "google_client_config" "default" {}

# Enable required services
resource "google_project_service" "services" {
  for_each = toset(var.services)
  service  = each.key

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = true
}

# Disable organization constraints
resource "google_project_organization_policy" "shielded_vm_disable" {
  constraint = "compute.requireShieldedVm"
  project = data.google_client_config.default.project

  boolean_policy {
    enforced = false
  }
}

resource "time_sleep" "wait_for_services" {
  depends_on = [
    google_project_service.services
  ]

  create_duration = "60s"
}


resource "google_storage_bucket" "bucket" {
  name          = var.project
  location      = "us-central1"
}


resource "google_service_account" "dev" {
  account_id   = "developer"
  display_name = "Custom SA for VM Instance"
}

resource "google_project_iam_binding" "dev_account" {
  project = var.project
  count = length(var.rolesList)
  role =  var.rolesList[count.index]
  members = [
    "serviceAccount:${google_service_account.dev.email}"
  ]
}


# Ubuntu VM in dev subnet
resource "google_compute_instance" "dev_vm" {
  name         = "dev-vm"
  machine_type = "e2-small"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dev.id
  }

  service_account {
    email  = google_service_account.dev.email
    scopes = ["cloud-platform"]
  }

}

# Copy VM in DMZ (public) subnet
resource "google_compute_instance" "copy_vm" {
  name         = "copy"
  machine_type = "e2-small"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dmz.id
  }

  service_account {
    email  = google_service_account.dev.email
    scopes = ["cloud-platform"]
  }

  tags = ["allow-ssh"]
}

# Firewall rule to allow SSH access to the copy VM
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}
