provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-private-cluster"
  project_id                 = var.project
  name                       = "platform"
  region                     = var.region
  zones                      = ["us-central1-a", "us-central1-b", "us-central1-f"]
  network                    = module.gcp-network.network_name
  subnetwork                 = local.subnet_names[index(module.gcp-network.subnets_names, "services")]
  ip_range_pods              = local.ip_pods
  ip_range_services          = local.ip_services
  horizontal_pod_autoscaling = true
  enable_private_endpoint    = true
  enable_private_nodes       = true
  master_ipv4_cidr_block     = "10.128.0.0/28"
  dns_cache                  = false
  deletion_protection        = false

  depends_on = [ module.project-services ]

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
    subnetwork = local.subnet_names[index(module.gcp-network.subnets_names, "dev")]
  }

  service_account {
    email  = module.sa-dev.email
    scopes = ["cloud-platform"]
  }

}
