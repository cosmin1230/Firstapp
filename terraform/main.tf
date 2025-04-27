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
  project     = var.gcp_project_id
  region      = var.gcp_region
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
    "iam.googleapis.com", // Critical, will be skipped in provisioner
    "cloudresourcemanager.googleapis.com", // Critical, will be skipped in provisioner
    "serviceusage.googleapis.com" // Critical, will be skipped in provisioner
  ])
  service = each.key

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      if [[ "${self.service}" != "iam.googleapis.com" && \
            "${self.service}" != "cloudresourcemanager.googleapis.com" && \
            "${self.service}" != "serviceusage.googleapis.com" ]]; then
        gcloud services disable ${self.service} --project=${self.project} --quiet --disable_dependent-services || true
      fi
    EOT
  }
}

# Network resources
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.gcp_region
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

  source_ranges = var.ssh_source_ranges
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = var.http_source_ranges
}

# GKE Cluster
resource "google_container_cluster" "gke" {
  name     = var.gke_cluster_name
  location = var.gcp_region

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  deletion_protection = false
  remove_default_node_pool = true
  initial_node_count       = 1

  depends_on = [google_project_service.apis]
}

resource "google_container_node_pool" "nodes" {
  name       = var.node_pool_name
  cluster    = google_container_cluster.gke.id
  location   = var.gcp_region

  autoscaling {
    min_node_count = var.node_pool_min_count
    max_node_count = var.node_pool_max_count
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size
    disk_type = var.node_disk_type
    oauth_scopes = var.node_oauth_scopes
  }
}

# ArgoCD Installation
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
  depends_on = [google_container_node_pool.nodes]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.argocd_namespace
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = var.argocd_chart_version
  atomic = true

  values = [
    file("${path.module}/values.yaml")
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# App of Apps Pattern
resource "kubernetes_manifest" "app_of_apps" {
  manifest = yamldecode(file("${path.module}/app-of-apps.yaml"))

  depends_on = [
    google_container_node_pool.nodes,  # Ensure the GKE node pool is ready
    helm_release.argocd,              # Ensure Argo CD is installed
    kubernetes_namespace.argocd,       # Ensure the namespace exists
    kubernetes_default.kubernetes
  ]
}