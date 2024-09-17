# Provider configuration
provider "google" {
  project = "platform001"
  region  = "us-central1"
}

# Enable required services
resource "google_project_service" "cloud_resource_manager_api" {
    service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "compute" {
    service = "compute.googleapis.com"
}

resource "google_project_service" "networking" {
    service = "servicenetworking.googleapis.com"
}

resource "google_project_service" "container" {
    service = "container.googleapis.com"
}

resource "google_project_service" "sqladmin" {
    service = "sqladmin.googleapis.com"
}

resource "google_project_service" "redis" {
    service = "redis.googleapis.com"
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "my-vpc"
  auto_create_subnetworks = false
}

# Disable organization constraints
resource "google_organization_policy" "disable_shielded_vm" {
  name         = "disable-shielded-vm"
  parent       = "organizations/your-organization-id"
  constraint   = "constraints/compute.requireShieldedVm"
  boolean_policy {
    enforced = false
  }
}
# Services subnet (large private one)
resource "google_compute_subnetwork" "services" {
  name          = "services-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
  private_ip_google_access = true
}

# Dev subnet (smaller private one)
resource "google_compute_subnetwork" "dev" {
  name          = "dev-subnet"
  ip_cidr_range = "10.0.2.0/26"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
  private_ip_google_access = true
}

# DMZ subnet (smaller one with internet access)
resource "google_compute_subnetwork" "dmz" {
  name          = "dmz-subnet"
  ip_cidr_range = "10.0.3.0/26"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
}

# Router for the DMZ subnet
resource "google_compute_router" "router" {
  name    = "dmz-router"
  region  = "us-central1"
  network = google_compute_network.vpc.id
}

# NAT gateway for the DMZ subnet
resource "google_compute_router_nat" "nat" {
  name                               = "dmz-nat"
  router                             = google_compute_router.router.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.dmz.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Ubuntu VM in dev subnet
resource "google_compute_instance" "dev_vm" {
  name         = "dev-vm"
  machine_type = "e2-small"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dev.id
  }
}

# Copy VM in DMZ (public) subnet
resource "google_compute_instance" "copy_vm" {
  name         = "copy"
  machine_type = "e2-small"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dmz.id
    access_config {
      // This empty block will create an ephemeral external IP
    }
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
  name     = "my-gke-cluster"
  location = "us-central1"

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.services.name

  enable_autopilot = true

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-range"
    services_secondary_range_name = "service-range"
  }
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
}

# Redis instance in services subnet
resource "google_redis_instance" "cache" {
  name           = "my-redis-instance"
  tier           = "BASIC"
  memory_size_gb = 1

  location_id             = "us-central1-a"
  alternative_location_id = "us-central1-f"

  authorized_network = google_compute_network.vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
}