resource "random_string" "random" {
  length  = 8
  lower   = true
  upper   = false
  special = false
  keepers = {
    vm_pos_boot_disk_size = var.vm_pos_boot_disk_size
    // Take into account the machine type as well
    machine_type = var.vm_pos_machine_type
    // Be aware of launch script changes
    launch_script_hash = md5(file("${path.module}/scripts/vm-start-up-script.sh"))
    load_script_hash   = md5(file("${path.module}/scripts/create_and_load_everything_from_scratch.sh"))
  }
}

resource "google_compute_disk" "ch_disk" {
  name = "${var.disk_clickhouse_name}-${random_string.random.result}"
  type = local.disk_type
  zone = var.vm_default_zone
  labels = {
    datatype = "clickhouse"
  }
}
resource "google_compute_disk" "es_disk" {
  name = "${var.disk_elastic_name}-${random_string.random.result}"
  type = local.disk_type
  zone = var.vm_default_zone
  labels = {
    datatype = "elasticsearch"
  }
}

resource "google_compute_instance" "vm" {
  name                      = "${var.module_wide_prefix_scope}-support-vm-${random_string.random.result}"
  machine_type              = var.vm_pos_machine_type
  zone                      = var.vm_default_zone
  allow_stopping_for_update = true
  can_ip_forward            = true

  boot_disk {
    initialize_params {
      image = var.vm_pos_boot_image
      type  = local.disk_type
      size  = var.vm_pos_boot_disk_size
    }
  }

  attached_disk {
    source = google_compute_disk.ch_disk.self_link
    // mounted under /dev/disk/by-id/google-ch
    device_name = var.disk_clickhouse_name
    mode        = "READ_WRITE"
  }

  attached_disk {
    source = google_compute_disk.es_disk.self_link
    // mounted under /dev/disk/by-id/google-es
    device_name = var.disk_elastic_name
    mode        = "READ_WRITE"
  }

  // WARNING - Does this machine need a public IP. No cloud routing for eu-dev.
  network_interface {
    network = "default"
    access_config {
      network_tier = "PREMIUM"
    }
  }

  metadata = {
    startup-script = templatefile(
      local.startup_script,
      {
        PROJECT_ID     = var.project_id,
        GC_ZONE        = var.vm_default_zone,
        CH_DISK        = var.disk_clickhouse_name,
        ES_DISK        = var.disk_elastic_name,
        ES_VERSION     = var.vm_elastic_search_version,
        CH_VERSION     = var.vm_clickhouse_version,
        GS_ETL_DATASET = var.gs_etl,
        IMAGE_PREFIX   = var.release_name
        DEP_BRANCH     = var.branch
        MODULE         = "loader_vm"
      }
    )
    google-logging-enabled = true
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  // We add the lifecyle configuration
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_service_account" "vm_service_account" {
  project      = var.project_id
  account_id   = "${var.module_wide_prefix_scope}-svc-${random_string.random.result}"
  display_name = "${var.module_wide_prefix_scope}-GCP-service-account"
}

// Roles ---
resource "google_project_iam_member" "gos_vm_role" {
  for_each = toset([
    # "roles/storage.admin",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    # "roles/compute.admin"
  ])
  role    = each.key
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
  project = var.project_id
}
