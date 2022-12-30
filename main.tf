provider "libvirt" {
  uri = "qemu:///session"
}

locals {
  disk_sizes = {
    "20GB" = 21474836480 # should be in bytes
    "10GB" = 10737418240
  }
}

resource "libvirt_pool" "default_pool" {
  name = "${var.cluster_name}-pool"
  type = "dir"
  path = "${var.default_pool_dir}/${var.cluster_name}-pool"
}

resource "libvirt_volume" "base" {
  name   = "flatcar-base"
  source = var.base_image
  pool   = libvirt_pool.default_pool.name
  format = "qcow2"
}

resource "libvirt_volume" "vm-disk" {
  for_each       = toset(var.machines)
  name           = "${var.cluster_name}-${each.key}-${md5(libvirt_ignition.ignition[each.key].id)}.qcow2"
  base_volume_id = libvirt_volume.base.id
  pool           = libvirt_pool.default_pool.name
  format         = "qcow2"
  depends_on = [
    libvirt_ignition.ignition
  ]
}

resource "libvirt_volume" "data-disk" {
  for_each = toset(var.machines)
  name     = "${var.cluster_name}-${each.key}-data-${md5(libvirt_ignition.ignition[each.key].id)}.qcow2"
  pool     = libvirt_pool.default_pool.name
  size     = local.disk_sizes["20GB"]
  format   = "qcow2"
}

resource "libvirt_ignition" "ignition" {
  for_each = toset(var.machines)
  name     = "${var.cluster_name}-${each.key}-ignition"
  pool     = libvirt_pool.default_pool.name
  content  = data.ct_config.vm-ignitions[each.key].rendered
}

resource "libvirt_domain" "machine" {
  for_each = toset(var.machines)
  name     = "${var.cluster_name}-${each.key}"
  vcpu     = var.virtual_cpus
  memory   = var.virtual_memory

  fw_cfg_name     = "opt/org.flatcar-linux/config"
  coreos_ignition = libvirt_ignition.ignition[each.key].id

  disk {
    volume_id = libvirt_volume.vm-disk[each.key].id
  }

  disk {
    volume_id = libvirt_volume.data-disk[each.key].id
  }

  graphics {
    listen_type = "address"
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }
}
