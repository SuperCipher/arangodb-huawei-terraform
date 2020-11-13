provider "huaweicloud" {
  region = var.region
  # domain_name = "my-account-name"
  # access_key  = "my-access-key"
  # secret_key  = "my-secret-key"
}

# # Create a VPC
# resource "huaweicloud_vpc" "example" {
#   name = "my_vpc"
#   cidr = "192.168.0.0/30"
# }


# Este template cria os seguintes recursos:
## 1 VPC e 1 Subnet dentro da mesma
## 1 instância de computação ECS Linux
## 1 Elastic IP, associado à instância, para conexão à mesma pela Internet
## 1 security group, liberando acesso originado da Internet para HTTP (TCP 80) e SSH (TCP 22)
## 1 keypar (apenas a chave pública) para autenticação por SSH na instância usando a chave privada

variable "vpc_cidr" { # Faixa de endereços da VPC
  default = "10.70.0.0/16"
}

variable "region" { # Faixa de endereços da VPC
  default = "ap-southeast-2"
}

# https://www.terraform.io/docs/providers/huaweicloud/r/vpc_v1.html
resource "huaweicloud_vpc_v1" "vpc_single_instance_1" {
  # region = # opcional; assumido a partir dos parâmetros do provider
  name = "vpc_single_instance_1"
  cidr = var.vpc_cidr
}

# https://www.terraform.io/docs/providers/huaweicloud/r/networking_subnet_v2.html
# https://www.terraform.io/docs/providers/huaweicloud/r/vpc_subnet_v1.html
resource "huaweicloud_vpc_subnet_v1" "subnet_1" {
  vpc_id = huaweicloud_vpc_v1.vpc_single_instance_1.id
  name   = "subnet_1"
  # Range da subnet e endereço do gateway são calculados automaticamente a partir da VPC
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
  image_name        = "Ubuntu 20.04 server 64bit"
  flavor_name       = "c3.large.2"
  availability_zone = "${var.region}a"
  key_pair          = huaweicloud_compute_keypair_v2.kp_1.name
  security_groups   = [huaweicloud_networking_secgroup_v2.secgroup_http_and_ssh.name]

  network {
    uuid = huaweicloud_vpc_subnet_v1.subnet_1.id
  }

  # Troubleshooting logs are /var/log/cloud-init*
  user_data = <<-EOT
    timedatectl set-timezone America/Sao_Paulo
    echo "Hello, the time is now $(date -R)" | tee /output.txt
    apt-get update
    apt-get install nginx --yes
    echo "<h1>Hello from Nginx</h1><br>My hostname is $(hostname)"> /var/www/html/index.html
  EOT

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
    charge_mode = "traffic" # cobrança por tráfego de dados ("traffic") ou reserva de banda ("bandwidth")
    share_type  = "PER"     # Banda dedicada ("PER") ou compartilhada ("WHOLE") com outras instâncias
    size        = 1         # Banda em Mbps (de 1 up até 300)
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
      # "cd arangodb/",
      # "curl -OL https://download.arangodb.com/arangodb37/DEBIAN/Release.key",
      # "sudo apt-key add - < Release.key",
      # "echo 'deb https://download.arangodb.com/arangodb37/DEBIAN/ /' | sudo tee /etc/apt/sources.list.d/arangodb.list",
      # "sudo apt-get install apt-transport-https",
      # "sudo apt-get update",
      # "sudo apt-get install arangodb3=3.7.3-1",
      # "sudo apt-get install arangodb3-dbg=3.7.3-1",
    ]
  }
  provisioner "local-exec" {
    command = "echo ${huaweicloud_vpc_eip_v1.eip_1.address} >> ips.txt"
  }
}
