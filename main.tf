terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.138.0"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = "ru-central1-a"
}

resource "yandex_compute_instance" "nextcloud_vm" {
  name        = "nextcloud-vm"
  platform_id = "standard-v1"
  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd842fimj1jg6vmfee6r"
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.default.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  connection {
    type        = "ssh"
    host        = self.network_interface[0].nat_ip_address
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y python3"
    ]
  }
}

resource "yandex_vpc_network" "network" {
  name = "nextcloud-network"
}

resource "yandex_vpc_subnet" "default" {
  name           = "nextcloud-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "null_resource" "ansible_provisioning" {
  depends_on = [yandex_compute_instance.nextcloud_vm]

  provisioner "local-exec" {
    command = <<EOT
      echo "[nextcloud]" > inventory.ini
      echo "${yandex_compute_instance.nextcloud_vm.network_interface[0].nat_ip_address} ansible_user=ubuntu" >> inventory.ini
      ansible-playbook -i inventory.ini playbook.yaml
    EOT
  }
}