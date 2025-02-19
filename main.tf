terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.138.0"
    }
  }
}

variable "zone" {
  default = "ru-central1-a"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.zone
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts-oslogin"
}

resource "yandex_vpc_network" "network" {
  name = "nextcloud-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "nextcloud-subnet"
  zone           = var.zone
  v4_cidr_blocks = ["192.168.10.0/24"]
  network_id     = yandex_vpc_network.network.id
}

resource "yandex_compute_instance" "server" {
  name        = "nextcloud-server"
  platform_id = "standard-v3"
  resources {
    cores         = 2
    memory        = 4
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }
  metadata = {
    ssh-keys = "ubuntu:${chomp(file("~/.ssh/id_rsa.pub"))}"
  }
}

output "public_ip" {
  value = yandex_compute_instance.server.network_interface.0.nat_ip_address
}