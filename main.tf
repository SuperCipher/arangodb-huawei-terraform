provider "huaweicloud" {
  region = var.region
  # domain_name = "my-account-name"
  # access_key  = "my-access-key"
  # secret_key  = "my-secret-key"
}


variable "vpc_cidr" {
  default = "10.70.0.0/16"
}

variable "region" {
  default = "ap-southeast-2"
}

# https://www.terraform.io/docs/providers/huaweicloud/r/vpc_v1.html
resource "huaweicloud_vpc_v1" "vpc_single_instance_1" {
  # region = 
  name = "vpc_single_instance_1"
  cidr = var.vpc_cidr
}

# https://www.terraform.io/docs/providers/huaweicloud/r/networking_subnet_v2.html
# https://www.terraform.io/docs/providers/huaweicloud/r/vpc_subnet_v1.html
resource "huaweicloud_vpc_subnet_v1" "subnet_1" {
  vpc_id = huaweicloud_vpc_v1.vpc_single_instance_1.id
  name   = "subnet_1"
  cidr       = cidrsubnet(huaweicloud_vpc_v1.vpc_single_instance_1.cidr, 8, 1)
  gateway_ip = cidrhost(cidrsubnet(huaweicloud_vpc_v1.vpc_single_instance_1.cidr, 8, 1), 1)

  # Internal DNS servers
  ## https://support.huaweicloud.com/intl/en-us/dns_faq/dns_faq_002.html
  primary_dns   = "100.125.1.250"
  secondary_dns = "100.125.3.250"
}

# https://www.terraform.io/docs/providers/huaweicloud/r/networking_secgroup_v2.html
resource "huaweicloud_networking_secgroup_v2" "secgroup_http_and_ssh" {
  name = "secgroup_http_and_ssh"
  # delete_default_rules = true # default false
}

resource "huaweicloud_networking_secgroup_rule_v2" "secrule_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup_v2.secgroup_http_and_ssh.id
}

resource "huaweicloud_networking_secgroup_rule_v2" "secrule_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup_v2.secgroup_http_and_ssh.id
}

resource "huaweicloud_networking_secgroup_rule_v2" "arango-web" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8529
  port_range_max    = 8529
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup_v2.secgroup_http_and_ssh.id
}

output "instance_internal_ip_addr" {
  value = huaweicloud_compute_instance_v2.test-server-vpc.network[0].fixed_ip_v4
}

output "instance_eip" {
  value = huaweicloud_vpc_eip_v1.eip_1.publicip[0].ip_address
}

# https://www.terraform.io/docs/providers/huaweicloud/r/compute_keypair_v2.html
resource "huaweicloud_compute_keypair_v2" "kp_1" {
  name       = "keypar_importada"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQChvo3WqxS+HzD2XaanROCzomRPzgkVtpjxmD9l3zQeAUCFghbwD07/DWJVVWoSWi1bYzgET5tft5YxnBXhnnFyljMUnpbHkMht1uHThVPRQkUAuE/JleLN4RGLa4M9cMKmcLqXXjGWKYZu2DhATOx92N3PFM7ij2xg0QmoPl+Qy4x1qotRzMd3dbjsRSE47B2ol6AXDvfdvu+FsBfP1ORZ3zVV6gWb+hjcOzhyAzxIX/fi7fpd/mGU4vsoNM3R6o07qrOELM9xqNRdJJGCDp/AGOSNzphNNIIIhXiI1K0KhMPSvU2kL464gSNRkQf37spSWerx4sqxxQre9XfdkRGpuMJGhrVur3kUjaTOWzruAURmurCBt+ZYbUvqAyGLX0L6fU9hBtG8fK59+rLK8SOYXCnQN9A6XGz9WN5iz3VEMG6qd2gtGNqtu8fT7sTZTCB+fhFUyg9ez2j+Z5bwmRTSUAK7R1tJ0zGvM6Gwcj+kYaT6jXEsoCXYgJs5pRcX6ExHQ3HtHy6V+BWcn4dU2zhADsuH9M2hl77Cin4l/vhLP1TigdBhthw1OTkLJg4FbfOEqDSmbX5lAzSXfnYSWg7I1lQSsFLMAF5fEqbYe5yIkpV64cRA27TpVKle52MiIP8al2lTjtyzKCLNNG4XV2JQ57OVv2wzHwYpyaYauQC+SQ=="
}


# https://www.terraform.io/docs/providers/huaweicloud/r/compute_instance_v2.html
# https://www.terraform.io/docs/providers/openstack/r/compute_instance_v2.html
# https://github.com/terraform-providers/terraform-provider-huaweicloud/blob/master/huaweicloud/resource_huaweicloud_compute_instance_v2.go
resource "huaweicloud_compute_instance_v2" "test-server-vpc" {
  name = "test-server-terraform-vpc"
  # image_id = "cbe0df31-1150-488a-a9b2-612c745e1be0"
  # image_name        = "Ubuntu 20.04 server 64bit"
  image_name        = "ArangoDB"
  flavor_name       = "c3.large.2"
  availability_zone = "${var.region}a"
  key_pair          = huaweicloud_compute_keypair_v2.kp_1.name
  security_groups   = [huaweicloud_networking_secgroup_v2.secgroup_http_and_ssh.name]

  network {
    uuid = huaweicloud_vpc_subnet_v1.subnet_1.id
  }

  tags = {
    terraform = "true" # exemplo de tag
  }
}

resource "huaweicloud_compute_eip_associate" "associated" {
  public_ip   = huaweicloud_vpc_eip_v1.eip_1.address
  instance_id = huaweicloud_compute_instance_v2.test-server-vpc.id
}

# https://www.terraform.io/docs/providers/huaweicloud/r/vpc_eip_v1.html
resource "huaweicloud_vpc_eip_v1" "eip_1" {
  publicip {
    type    = "5_bgp" # only "5_bgp"is supported: https://support.huaweicloud.com/en-us/api-eip/eip_api_0001.html
    port_id = huaweicloud_compute_instance_v2.test-server-vpc.network[0].port
  }
  bandwidth {
    name        = "test_bw"
    charge_mode = "traffic"
    share_type  = "PER"
    size        = 1
  }
}


resource "null_resource" "preparation" {

  connection {
    host        = huaweicloud_vpc_eip_v1.eip_1.address # don't forget  this option.
    user        = "root"
    timeout     = "30s"
    private_key = file("/Users/naach/.ssh/huawei-terraform-ecs_rsa")
    agent       = false
  }

  # provisioner "file" {
  #   source      = "./tfvars"
  #   destination = "/tmp/"
  # }

  provisioner "remote-exec" {
    inline = [
      "mkdir /root/arangodb2",
    ]
  }
  provisioner "local-exec" {
    command = "echo ${huaweicloud_vpc_eip_v1.eip_1.address} >> ips.txt"
  }
}
