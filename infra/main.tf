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


# VPC
resource "google_compute_network" "vpc" {
  depends_on = [time_sleep.wait_for_services]
  name                    = "genaiplatform"
  auto_create_subnetworks = false
}

# Services subnet (large private one)
resource "google_compute_subnetwork" "services" {
  name          = "services-subnet"
  ip_cidr_range = "10.0.0.0/17"
  region        = data.google_client_config.default.region
  network       = google_compute_network.vpc.id
  private_ip_google_access = true
}

# Dev subnet (smaller private one)
resource "google_compute_subnetwork" "dev" {
  name          = "dev-subnet"
  ip_cidr_range = "10.0.128.0/18"
  region        = data.google_client_config.default.region
  network       = google_compute_network.vpc.id
  private_ip_google_access = true
}

# DMZ subnet (smaller one with internet access)
resource "google_compute_subnetwork" "dmz" {
  name          = "dmz-subnet"
  ip_cidr_range = "10.0.192.0/18"
  region        = data.google_client_config.default.region
  network       = google_compute_network.vpc.id
}

# Reserved range for Privete Access?
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.vpc.id
}

# Private access
resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Router for the DEV subnet
resource "google_compute_router" "dev_router" {
  name    = "dev-router"
  region  = data.google_client_config.default.region
  network = google_compute_network.vpc.id
}

# NAT gateway for the DMZ subnet
resource "google_compute_router_nat" "dev_nat" {
  name                               = "dev-nat"
  router                             = google_compute_router.dev_router.name
  region                             = data.google_client_config.default.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.dev.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Router for the DMZ subnet
resource "google_compute_router" "dmz_router" {
  name    = "dmz-router"
  region  = data.google_client_config.default.region
  network = google_compute_network.vpc.id
}

# NAT gateway for the DMZ subnet
resource "google_compute_router_nat" "dmz_nat" {
  name                               = "dmz-nat"
  router                             = google_compute_router.dmz_router.name
  region                             = data.google_client_config.default.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.dmz.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
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

# GKE Autopilot cluster in services subnet
resource "google_container_cluster" "primary" {
  name     = "platform"
  location = "us-central1"

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.services.name

  enable_autopilot = true
  deletion_protection = false

}

# Cloud SQL Postgres instance in services subnet
resource "google_sql_database_instance" "postgres" {
  name             = "my-postgres-instance"
  database_version = "POSTGRES_13"
  region           = "us-central1"

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      private_network = google_compute_network.vpc.id
    }
  }

  deletion_protection = false
  depends_on = [ google_service_networking_connection.default ]
}

# Redis instance in services subnet
resource "google_redis_instance" "cache" {
  name           = "my-redis-instance"
  tier           = "BASIC"
  memory_size_gb = 1

  region = "us-cemtral1"
  
  authorized_network = google_compute_network.vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  depends_on = [ google_service_networking_connection.default ]
}