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
