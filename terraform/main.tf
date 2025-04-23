terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "google" {
  project     = "neat-chain-457017-u0"
  region      = "us-central1"
  credentials = file("~/.config/gcloud/application_default_credentials.json")
}

data "google_client_config" "default" {}

# Configure kubernetes provider after GKE cluster is created
provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  load_config_file       = false
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com"
  ])
  service = each.key

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      if [ "${self.service}" != "iam.googleapis.com" ]; then
        gcloud services disable ${self.service} --project=${self.project} --quiet || true
      fi
    EOT
  }
}

# Network resources
resource "google_compute_network" "vpc" {
  name                    = "my-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "my-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
}

# Firewall rules
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["79.177.153.240/32"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# GKE Cluster
resource "google_container_cluster" "gke" {
  name     = "my-gke-cluster"
  location = "us-central1-a"

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  deletion_protection = false
  remove_default_node_pool = true
  initial_node_count       = 1

  depends_on = [google_project_service.apis]
}

resource "google_container_node_pool" "nodes" {
  name       = "my-node-pool"
  cluster    = google_container_cluster.gke.id
  location   = "us-central1-a"

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
    ]
  }
}

# ArgoCD Installation
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
  depends_on = [google_container_node_pool.nodes]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "7.8.26"
  atomic = true

  values = [
    file("${path.module}/values.yaml")
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# App of Apps Pattern
resource "kubectl_manifest" "app_of_apps" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: app-of-apps
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: "https://github.com/cosmin1230/Firstapp"
        targetRevision: master                            
        path: "terraform"                                 
      destination:
        server: "https://kubernetes.default.svc"
        namespace: "argocd"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.argocd
  ]
}