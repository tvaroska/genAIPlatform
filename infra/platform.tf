# GKE Autopilot cluster in services subnet
resource "google_container_cluster" "primary" {
  name     = "platform"
  location = "us-central1"

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.services.name

  enable_autopilot = true
  deletion_protection = false

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
#    master_ipv4_cidr_block  = "172.16.0.0/28"  # Specify a /28 CIDR block for the master
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
