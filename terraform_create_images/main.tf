// Open Targets Platform Infrastructure
// Author: Cinzia Malangone <cinzia.malangone@gmail.com>

// --- Provider Configuration --- //
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.70.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "3.70.0"
    }
  }
}

provider "google" {
  region  = var.config_gcp_default_region
  project = var.config_project_id
}


provider "google-beta" {
  project = var.config_project_id
  region  = var.config_gcp_default_region
  #zone   = local.gcp_zone
}

module "backend_pos_vm" {
  module_wide_prefix_scope = "${var.config_script_name}-vm"
  source                   = "./modules/loader_vm"

  project_id = var.config_project_id

  // Region and zone
  vm_default_zone           = var.config_gcp_default_zone
  vm_pos_boot_image         = var.config_vm_pos_boot_image
  vm_pos_boot_disk_size     = var.config_vm_pos_boot_disk_size
  vm_pos_machine_type       = var.config_vm_pos_machine_type
  gs_etl                    = var.config_gs_etl
  vm_elasticsearch_uri      = "localhost"
  vm_clickhouse_uri         = "localhost"
  vm_elastic_search_version = var.config_vm_elastic_search_version
  vm_clickhouse_version     = var.config_vm_clickhouse_version
  release_name              = var.config_release_name
}
