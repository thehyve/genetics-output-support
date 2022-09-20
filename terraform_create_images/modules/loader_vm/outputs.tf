output "vm_name" {
  value = join("", google_compute_instance.vm.*.name)
}
