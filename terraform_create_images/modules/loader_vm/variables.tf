// --- Module input parameters --- //
// General deployment input parameters --- //

variable "project_id" {
  description = "Default project to use when not specified in the module"
  type        = string
}

variable "module_wide_prefix_scope" {
  description = "The prefix provided here will scope names for those resources created by this module, default 'otpdeves'"
  type        = string
  default     = "otdevgos"
}

variable "release_name" {
  description = "Open Targets Genetics release name, parameter for the images"
  type        = string
}

// --- ETL info --- //
variable "gs_etl" {
  description = "Output of the ETL [root]. Eg. open-targets-data-releases/21.04/output"
  type        = string
}

// --- VM info --- //
variable "vm_pos_boot_image" {
  description = "Boot image configuration for POS VM"
  type        = string
  default     = "debian-10"
}

variable "vm_default_zone" {
  description = "Default zone when not specified in the module"
  type        = string
}

variable "vm_pos_boot_disk_size" {
  description = "POS VM boot disk size, default '500GB'"
  type        = string
  default     = 500
}

variable "vm_pos_machine_type" {
  description = "Machine type for POS vm"
  type        = string
}

variable "vm_elasticsearch_uri" {
  description = "Elasticsearch Server"
  type        = string
  default     = "localhost"
}
variable "vm_elastic_search_version" {
  description = "Elastic Search Docker Image version to use"
  type        = string
}
variable "vm_clickhouse_version" {
  description = "Clickhouse Docker Image version to use"
  type        = string
  default     = "22.3.12.19-alpine"
}
variable "vm_clickhouse_uri" {
  description = "Clickhouse Server"
  type        = string
  default     = "localhost"
}

// -- Disk info -- //
variable "disk_elastic_name" {
  description = "Disk to hold Elasticsearch data"
  type        = string
  default     = "es-disk"
}
variable "disk_clickhouse_name" {
  description = "Disk to hold Clickhouse data"
  type        = string
  default     = "ch-disk"
}

variable "branch" {
  description = "The git branch to gather the SQL and other loading scripts."
  type        = string
  default     = "main"
}
