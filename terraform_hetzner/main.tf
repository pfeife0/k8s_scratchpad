variable "hcloud_token" {}

variable "ssh_fingerprint" {}

variable "username" {}

variable "sshkey_location" {}

#variable "master_ip" {}

variable "k3s_token" {}
 
variable "private_ip_range" {
    default="10.0.10.10-10.0.10.20"
}
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
}

locals {
  ip_range_start = split("-", var.private_ip_range)[0]
  ip_range_end   = split("-", var.private_ip_range)[1]

  # Note that this naively only works for IP ranges using the same first three octects
  ip_range_first_three_octets = join(".", slice(split(".", local.ip_range_start), 0, 3))
  ip_range_start_fourth_octet = split(".", local.ip_range_start)[3]
  ip_range_end_fourth_octet   = split(".", local.ip_range_end)[3]

  list_of_final_octet  = range(local.ip_range_start_fourth_octet, local.ip_range_end_fourth_octet)
  list_of_ips_in_range = formatlist("${local.ip_range_first_three_octets}.%s", local.list_of_final_octet)
}


data "hcloud_ssh_key" "ssh_key" {
  fingerprint = var.ssh_fingerprint
}

data "template_file" "sshkey" {
  template = "${file(var.sshkey_location)}"
}

# Define Hetzner provider
provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "dev-ks3-1" {
  name = "dev-ks3-1"
  image = "ubuntu-22.04"
  server_type = "cpx11"
  ssh_keys  = ["${data.hcloud_ssh_key.ssh_key.id}"]
  datacenter = "ash-dc1"
  
  network {
    network_id = "2161175"
    ip = local.list_of_ips_in_range[0]
  }  
  user_data = templatefile( "${path.module}/cloud-init-master.yaml", {
    username = var.username
    sshkey-admin = "${data.template_file.sshkey.rendered}"   
    k3s_token = var.k3s_token
    private_ip = local.list_of_ips_in_range[0]
  })
}


resource "hcloud_server" "dev-ks3-2" {
  name = "dev-ks3-2"
  image = "ubuntu-22.04"
  server_type = "cpx11"
  ssh_keys  = ["${data.hcloud_ssh_key.ssh_key.id}"]
  datacenter = "ash-dc1"
  
  network {
    network_id = "2161175"
    ip = local.list_of_ips_in_range[1]
  }  
  
  user_data = templatefile( "${path.module}/cloud-init.yaml", {
    username = var.username
    sshkey-admin = "${data.template_file.sshkey.rendered}" 
    master_ip = local.list_of_ips_in_range[0] 
    k3s_token = var.k3s_token
    private_ip = local.list_of_ips_in_range[1]
  })
  
  depends_on = [hcloud_server.dev-ks3-1]
}

resource "hcloud_server" "dev-ks3-3" {
  name = "dev-ks3-3"
  image = "ubuntu-22.04"
  server_type = "cpx11"
  ssh_keys  = ["${data.hcloud_ssh_key.ssh_key.id}"]
  datacenter = "ash-dc1"
  
  network {
    network_id = "2161175"
    ip = local.list_of_ips_in_range[2]
  }  
  
  user_data = templatefile( "${path.module}/cloud-init.yaml", {
    username = var.username
    sshkey-admin = "${data.template_file.sshkey.rendered}" 
    master_ip = local.list_of_ips_in_range[0] #var.master_ip
    k3s_token = var.k3s_token
    private_ip = local.list_of_ips_in_range[2]
  })
  
  depends_on = [hcloud_server.dev-ks3-1]
}

# Output server IPs
output "dev-ks3-1-ip" {
 value = "${hcloud_server.dev-ks3-1.ipv4_address}"
}

output "dev-ks3-2-ip" {
 value = "${hcloud_server.dev-ks3-2.ipv4_address}"
}

output "dev-ks3-3-ip" {
 value = "${hcloud_server.dev-ks3-3.ipv4_address}"
}

output "cloud-init-master_file" {
  value = "${data.template_file.cloud-init-yaml-master.rendered}"
}

output "cloud-init_file" {
  value = "${data.template_file.cloud-init-yaml.rendered}"
}