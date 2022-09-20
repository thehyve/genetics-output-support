locals {
  roles            = ["roles/compute.admin", "roles/logging.viewer", "roles/compute.instanceAdmin", "roles/storage.objectViewer", "roles/storage.admin"]
  remote_user_name = "provisioner"
  disk_type        = "pd-ssd"
  startup_script   = "${path.module}/scripts/vm-start-up-script.sh"
}
