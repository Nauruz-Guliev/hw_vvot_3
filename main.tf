terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.138.0"
    }
  }
}

variable "zone" {
  type        = string
  default     = "ru-central1-a"
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

resource "yandex_compute_disk" "boot-disk" {
  name     = "vvot03-boot-disk"
  type     = "network-ssd"
  image_id = data.yandex_compute_image.ubuntu.id
  size     = 20 
}

resource "yandex_compute_instance" "server" {
  name        = "vvot03-server-nextcloud"
  platform_id = "standard-v3"
  hostname    = "nextcloud"
  
  resources {
    core_fraction = 20
    cores         = 2
    memory        = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_vpc_network" "network" {
  name = "vvot03-nextcloud-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "vvot03-nextcloud-subnet"
  zone           = var.zone
  v4_cidr_blocks = ["192.168.10.0/24"]
  network_id     = yandex_vpc_network.network.id
}

resource "null_resource" "ansible-provisioner" {
  depends_on = [yandex_compute_instance.server]
  # в начале еще 2 минуты подождем, чтобы успело запуститься
  provisioner "local-exec" {
    command = <<EOT
      sleep 120 
      echo "[nextcloud]" > inventory.ini
      echo "${yandex_compute_instance.server.network_interface.0.nat_ip_address} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa" >> inventory.ini
      ansible-playbook -i inventory.ini playbook.yaml
    EOT
  }
}

output "public_ip" {
  value = yandex_compute_instance.server.network_interface.0.nat_ip_address
}