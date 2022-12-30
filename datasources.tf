data "ct_config" "vm-ignitions" {
  for_each = toset(var.machines)
  content  = data.template_file.vm-configs[each.key].rendered
}

data "template_file" "vm-configs" {
  for_each = toset(var.machines)
  template = file("${path.module}/cl/machine-mynode.yaml.tmpl")

  vars = {
    ssh_keys = jsonencode(var.ssh_keys)
    name     = each.key
  }
}
