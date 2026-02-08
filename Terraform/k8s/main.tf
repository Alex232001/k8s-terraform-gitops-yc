terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.92" 
    }
  }
  required_version = ">= 0.13"

}

provider "yandex" {
  zone = "ru-central1-a"
  folder_id = var.folder_id

  service_account_key_file = "sa-key.json"
}

locals {
  common_tags = {
    Project     = "k8s-cluster"
    Environment = "development"
    ManagedBy   = "terraform"
  }

  # Все необходимые роли для Service Account
  sa_roles = [
    "k8s.clusters.agent",
    "vpc.publicAdmin",
    "container-registry.images.puller",
    "kms.keys.encrypterDecrypter",
    "dns.admin",  
    "load-balancer.admin"
  ]

  #sa_name = "${var.cluster_name}-sa"
  sa_name = "k8s-manager-sa"
}


# DNS зона
resource "yandex_dns_zone" "stellarclaw_zone" {
  name        = "stellarclaw-zone"
  zone        = "stellarclaw.ru."
  public      = true
  description = "DNS zone for stellarclaw.ru domain"
}

# DNS A запись для frontend субдомена
resource "yandex_dns_recordset" "frontend" {
  zone_id = yandex_dns_zone.stellarclaw_zone.id
  name    = "frontend.stellarclaw.ru."
  type    = "A"
  ttl     = 300
  data    = [yandex_kubernetes_cluster.zonal_cluster.master[0].external_v4_address]

  depends_on = [
    yandex_kubernetes_cluster.zonal_cluster,
    yandex_dns_zone.stellarclaw_zone
  ]
}

# Сеть для кластера
resource "yandex_vpc_network" "k8s_network" {
  name = "k8s-network"
}

resource "yandex_vpc_subnet" "k8s_subnet" {
  name           = "k8s-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s_network.id
  v4_cidr_blocks = ["10.130.0.0/24"]
}

# Service Account
resource "yandex_iam_service_account" "k8s_manager" {
  name        = local.sa_name
  description = "Service account for Kubernetes cluster ${local.sa_name} "
}

resource "yandex_resourcemanager_folder_iam_member" "sa_roles" {
  for_each = toset(local.sa_roles)

  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.k8s_manager.id}"
}

# Создание статического ключа для сервисного аккаунта
resource "yandex_iam_service_account_key" "k8s_manager_key" {
  service_account_id = yandex_iam_service_account.k8s_manager.id
  description        = "Static key for External DNS"
  key_algorithm      = "RSA_4096"
}

resource "local_file" "service_account_key" {
  content = jsonencode({
    "id"                 = yandex_iam_service_account_key.k8s_manager_key.id
    "service_account_id" = yandex_iam_service_account.k8s_manager.id
    "created_at"         = yandex_iam_service_account_key.k8s_manager_key.created_at
    "key_algorithm"      = "RSA_4096"
    "public_key"         = yandex_iam_service_account_key.k8s_manager_key.public_key
    "private_key"        = yandex_iam_service_account_key.k8s_manager_key.private_key
  })
  filename = "service-account-key.json"
}

# Output для JSON ключа
output "service_account_key_json_k8s_dns" {
  value     = jsonencode({
    "id"                 = yandex_iam_service_account_key.k8s_manager_key.id
    "service_account_id" = yandex_iam_service_account.k8s_manager.id
    "created_at"         = yandex_iam_service_account_key.k8s_manager_key.created_at
    "key_algorithm"      = "RSA_4096"
    "public_key"         = yandex_iam_service_account_key.k8s_manager_key.public_key
    "private_key"        = yandex_iam_service_account_key.k8s_manager_key.private_key
  })
  sensitive = true
  description = "Full JSON key for Dns create "
}

# Claster Manager
resource "yandex_kubernetes_cluster" "zonal_cluster" {
  name        = "name"
  description = "description"

  network_id = yandex_vpc_network.k8s_network.id

  master {
    version = "1.30"
    zonal {
      zone      = yandex_vpc_subnet.k8s_subnet.zone
      subnet_id = yandex_vpc_subnet.k8s_subnet.id
    }

    public_ip = true

    #security_group_ids = ["${yandex_vpc_security_group.security_group_name.id}"]

    # Обновление  и время 
    maintenance_policy {
      auto_upgrade = true

      maintenance_window {
        start_time = "15:00"
        duration   = "3h"
      }
    }

    # Логирование позже
    #master_logging {
    #  enabled                    = true
    #  log_group_id               = yandex_logging_group.log_group_resoruce_name.id
    #  kube_apiserver_enabled     = true
    #  cluster_autoscaler_enabled = true
    #  events_enabled             = true
    #  audit_enabled              = true
    #}

    # instance_type {
    #   resource_preset_id = "s2.medium"  # ← это как раз для manager
    #   memory             = 8  # 8
    #   cores              = 2  # 4 
    # }

    #scale_policy {
    #  auto_scale {
    #    min_resource_preset_id = "s-c4-m16"
    #  }
    #}
  }

  service_account_id = yandex_iam_service_account.k8s_manager.id
  node_service_account_id = yandex_iam_service_account.k8s_manager.id

  labels = {
    env  = "dev"
    role = "manager"
  }

  release_channel         = "RAPID"
  network_policy_provider = "CALICO"

  # kms_provider {
  #   key_id = yandex_kms_symmetric_key.kms_key_resource_name.id
  # }

  workload_identity_federation {
    enabled = true
  }

  # ЗАВИСИМОСТИ для кластера
  depends_on = [
    yandex_vpc_subnet.k8s_subnet,
    yandex_resourcemanager_folder_iam_member.sa_roles
  ]

}


// Create a new Managed Kubernetes Node Group
//
resource "yandex_kubernetes_node_group" "node_group_k8s" {
  cluster_id  = yandex_kubernetes_cluster.zonal_cluster.id
  name        = "name"
  description = "description"
  version     = "1.30"

  labels = {
    env  = "dev"
    role = "node"
  }

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = ["${yandex_vpc_subnet.k8s_subnet.id}"]
    }

    #metadata = {
    #  ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
    #}

    resources {
      memory = 8
      cores  = 4
    }

    boot_disk {
      type = "network-ssd"
      size = 64
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true

    maintenance_window {
      day        = "monday"
      start_time = "15:00"
      duration   = "3h"
    }

    maintenance_window {
      day        = "friday"
      start_time = "10:00"
      duration   = "4h30m"
    }
  }

  # Node Group зависит от полного создания кластера
  depends_on = [yandex_kubernetes_cluster.zonal_cluster]

}

# Автоматическое получение конфигурации
#resource "null_resource" "configure_kubectl" {
#  depends_on = [yandex_kubernetes_cluster.zonal_cluster]
#  
#  provisioner "local-exec" {
#    command = "yc managed-kubernetes cluster get-credentials --id ${yandex_kubernetes_cluster.zonal_cluster.id} --external"
#  }
#}

# Вывод команды для подключения
output "cluster_connection_command" {
  value = "yc managed-kubernetes cluster get-credentials --id ${yandex_kubernetes_cluster.zonal_cluster.id} --external"
}

# Вывод ID кластера
output "cluster_id" {
  value = yandex_kubernetes_cluster.zonal_cluster.id
}
