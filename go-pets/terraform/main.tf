terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.53"
    }
  }
}

provider "google" {
  project = var.project
}

locals {
  service_name   = "go-pets"

  deployment_name = "go-pets"
  pets_worker_sa  = "serviceAccount:${google_service_account.pets_worker.email}"
}

resource "google_project_service" "run" {
  service = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "datastore" {
  service = "datastore.googleapis.com"
  disable_on_destroy = false
}

# Create a service account
resource "google_service_account" "pets_worker" {
  account_id   = "pets-worker"
  display_name = "Pets Worker SA"
}

# Set permissions
resource "google_project_iam_binding" "service_permissions" {
  role       = "roles/run.invoker"
  members    = [local.pets_worker_sa]
  depends_on = [google_service_account.pets_worker]
}