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
  location = "us_central"
  
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

resource "google_app_engine_application" "app" {
  project     = var.project
  location_id = local.location
  database_type = "CLOUD_DATASTORE_COMPATIBILITY"
}

# Set permissions
resource "google_project_iam_binding" "service_permissions" {
  for_each = toset([
    "run.invoker", "datastore.owner","appengine.appAdmin"
  ])
  
  role       = "roles/${each.key}"
  members    = [local.pets_worker_sa]
  depends_on = [google_service_account.pets_worker]
}

# The Cloud Run service
resource "google_cloud_run_service" "default" {
  name                       = local.service_name
  location                   = var.region
  autogenerate_revision_name = true

  template {
    spec {
      service_account_name = google_service_account.pets_worker.email
      containers {
        image = data.external.image_digest.result.image
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.run]
}

# Set service public
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
  depends_on  = [google_cloud_run_service.default]
}


# WORKAROUND 
data "external" "image_digest" {
  program = ["bash", "../scripts/get_latest_tag.sh", var.project, local.service_name]
}

resource "google_datastore_index" "default" {
  kind = "Pet"
  properties {
    name = "added"
    direction = "ASCENDING"
  }
  properties {
    name = "caption"
    direction = "ASCENDING"
  }
  properties {
      name = "email"
      direction = "ASCENDING"
  }
  properties {
      name = "image"
      direction = "ASCENDING"
  }
  properties {
      name = "likes"
      direction = "ASCENDING"
  }
  properties {
      name = "owner"
      direction = "ASCENDING"
  }
  properties {
        name = "petname"
        direction = "ASCENDING"
  }
  
  depends_on = [google_app_engine_application.app]
}