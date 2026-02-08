# Kubernetes Cluster с Terraform & GitOps

## Описание проекта

Infrastructure as Code (IaC) для развертывания управляемого Kubernetes кластера в Yandex Cloud. Проект автоматизирует создание  K8s кластера с DNS, балансировщиками нагрузки, SSL сертификатами и пайплайнами CI/CD.

**Основа проекта**: Модифицированная версия [Google Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) - демонстрационного микросервисного приложения от Google.

<div align="center">
  
## Архитектура

</div>

```ascii
                              ┌───────────────────────────────────────────────────────────┐
                              │                     Yandex Cloud                          │
                              ├───────────────────────────────────────────────────────────┤
                              │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
                              │  │   DNS Zone  │◄──►│   Cluster   │◄──►│   Registry  │    │
                              │  │ stellarclaw │    │   K8s       │    │  Container  │    │
                              │  └─────────────┘    └─────────────┘    └─────────────┘    │
                              │         │                       │               │         │
                              │         ▼                       ▼               ▼         │
                              │  ┌─────────────┐    ┌──────────────────────┐              │
                              │  │  DNS Records│    │  Node Groups         │              │
                              │  │   A, CNAME  │    │  (Worker Nodes)      │              │
                              │  └─────────────┘    └──────────────────────┘              │
                              └───────────────────────────────────────────────────────────┘
                                                                   │
                                                                   ▼
                              ┌───────────────────────────────────────────────────────────┐
                              │                    Kubernetes Cluster                     │
                              ├───────────────────────────────────────────────────────────┤
                              │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
                              │  │  Ingress    │  │  Cert       │  │  External   │        │
                              │  │  Nginx      │  │  Manager    │  │  DNS        │        │
                              │  └─────────────┘  └─────────────┘  └─────────────┘        │
                              │         │               │               │                 │
                              │         ▼               ▼               ▼                 │
                              │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
                              │  │  ArgoCD     │  │  Let's      │  │  Automated  │        │
                              │  │  (GitOps)   │  │  Encrypt    │  │  DNS        │        │
                              │  └─────────────┘  └─────────────┘  └─────────────┘        │
                              │         │                                                 │
                              │         ▼                                                 │
                              │  ┌────────────────────────────────────────────┐           │
                              │  │         Microservices Applications         │           │
                              │  │  • Frontend                                │           │
                              │  │  • Product Catalog                         │           │
                              │  │  • Cart Service                            │           │
                              │  │  • Checkout Service                        │           │
                              │  │  • ... (11 сервисов)                       │           │
                              │  └────────────────────────────────────────────┘           │
                              └───────────────────────────────────────────────────────────┘
```

## Технологический стек

- **Инфраструктура**: Terraform 
- **Контейнеризация**: Docker, Containerd
- **Оркестрация**: Kubernetes 
- **Облачный провайдер**: Yandex Cloud
- **CI/CD**: GitHub Actions
- **GitOps**: ArgoCD
- **Ingress**: Nginx Ingress Controller
- **Сертификаты**: Cert-Manager + Let's Encrypt
- **DNS**: ExternalDNS
- **Реестр образов**: Yandex Container Registry

## CI/CD Pipeline

### Workflow 1: Создание кластера kubernetes
- **Триггер**: workflow_dispatch 
```yaml
on:
  workflow_dispatch:  
```

### Workflow 2: Сборка микросервисов 
- **Триггер**: pull_request
```yaml
name: Build All Services
on:
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened, closed] 
  workflow_dispatch:

```

### Workflow 3: Удаление кластера kubernetes
- **Триггер**: workflow_dispatch 
```yaml
on:
  workflow_dispatch:  
```


