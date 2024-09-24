variable "project" {
  type        = string
  description = "Project ID"
}

variable "region" {
    type        = string
    description = "Region"
    default     = "us-central1"
}

variable "services" {
  type        = list(string)
  description = "Enable services - list"
  default = [
    "iam.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "aiplatform.googleapis.com",
    "storage.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com"
  ]
}
