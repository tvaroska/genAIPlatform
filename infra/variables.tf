variable "project" {
  type        = string
  description = "Project ID"
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

variable "rolesList" {
  type = list(string)
  default = ["roles/storage.legacyBucketOwner"]
}
