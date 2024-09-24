# Provider configuration
provider "google" {
  project = var.project
  region  = var.region
}


data "google_client_config" "default" {}

locals{
    ip_pods                = "platform-pods"
    ip_services            = "platform-services"
    subnet_names           = [for subnet_self_link in module.gcp-network.subnets_self_links : split("/", subnet_self_link)[length(split("/", subnet_self_link)) - 1]]
}

# Enable required services
module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 17.0"

  project_id                  = var.project

  activate_apis = var.services
}

# Disable organization constraints
resource "google_project_organization_policy" "shielded_vm_disable" {
  constraint = "compute.requireShieldedVm"
  project = data.google_client_config.default.project

  boolean_policy {
    enforced = false
  }
}

# Service account for VM
module "sa-dev" {
  source  = "terraform-google-modules/service-accounts/google//modules/simple-sa"
  version = "~> 4.0"

  project_id = var.project
  name       = "developer"
  project_roles = [
    "roles/cloudbuild.builds.editor",
    "roles/container.developer",
    "roles/artifactregistry.repoAdmin"
  ]
}

# Bucket
module "bucket" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 6.1"
  project_id  = var.project
  names = [var.project]
  set_admin_roles = true
  admins = [module.sa-dev.iam_email]
}

# VPC Network - 3 subnets
module "gcp-network" {
  source  = "terraform-google-modules/network/google"
  version = ">= 7.5"

  project_id   = var.project
  network_name = "platform"

  subnets = [
    {
      subnet_name   = "services"
      subnet_ip     = "10.0.0.0/17"
      subnet_region = var.region
    },
    {
      subnet_name   = "dev"
      subnet_ip     = "10.0.128.0/18"
      subnet_region = var.region
    },
    {
      subnet_name   = "dmz"
      subnet_ip     = "10.0.192.0/18"
      subnet_region = var.region
    },
  ]

  secondary_ranges = {
    ("services") = [
      {
        range_name    = local.ip_pods
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = local.ip_services
        ip_cidr_range = "192.168.64.0/18"
      },
    ]
  }

  depends_on = [ module.project-services ]

}

# Router for VPC
resource "google_compute_router" "router" {
  project = var.project
  name    = "nat-router"
  network = module.gcp-network.network_name
  region  = var.region
}

# NAT for (in future) dmz and dev subnet
module "cloud-nat" {
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 5.0"

  project_id                         = var.project
  region                             = var.region
  router                             = google_compute_router.router.name
  name                               = "nat-config"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES" # TODO: replace with two subnets
}

