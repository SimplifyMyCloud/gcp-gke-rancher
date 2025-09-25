variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "GCP Zone for single-zone resources"
  type        = string
  default     = "us-west1-a"
}

variable "environment" {
  description = "Environment name (e.g., poc, test, prod)"
  type        = string
  default     = "poc"
}

variable "allowed_iap_users" {
  description = "List of users/service accounts allowed to use IAP"
  type        = list(string)
  default     = []
}

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "gke-rancher-testdrive"
}

variable "gke_node_count" {
  description = "Number of nodes in GKE cluster"
  type        = number
  default     = 3
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}