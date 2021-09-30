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
  service_name   = "go-api"

  deployment_name = "go-api"
  api_worker_sa  = "serviceAccount:${google_service_account.api_worker.email}"
  
  cloud_run_url = google_cloud_run_service.api.status[0].url
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

# Create a service account
resource "google_service_account" "api_worker" {
  account_id   = "api-worker"
  display_name = "API Worker SA"
}

# Set permissions
resource "google_project_iam_binding" "service_permissions" {
  for_each = toset([
    "run.invoker","appengine.appAdmin"
  ])
  
  role       = "roles/${each.key}"
  members    = [local.api_worker_sa]
  depends_on = [google_service_account.api_worker]
}

# The Cloud Run service
resource "google_cloud_run_service" "api" {
  name                       = local.service_name
  location                   = var.region
  autogenerate_revision_name = true

  template {
    spec {
      service_account_name = google_service_account.api_worker.email
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
  location = google_cloud_run_service.api.location
  project  = google_cloud_run_service.api.project
  service  = google_cloud_run_service.api.name

  policy_data = data.google_iam_policy.noauth.policy_data
  depends_on  = [google_cloud_run_service.api]
}


# WORKAROUND 
data "external" "image_digest" {
  program = ["bash", "../scripts/get_latest_tag.sh", var.project, local.service_name]
}

resource "google_endpoints_service" "openapi_service" {
  service_name   = "${replace(local.cloud_run_url, "https://", "")}"
  project        = var.project
  openapi_config = <<EOF
    swagger: '2.0'
    info:
      title: Cloud Endpoints + Cloud Run
      description: Sample API on Cloud Endpoints with a Cloud Run backend
      version: 1.0.0
    host: "${replace(local.cloud_run_url, "https://", "")}"
    schemes:
      - https
    produces:
      - application/json
    x-google-backend:
      address: "${local.cloud_run_url}"
      protocol: h2
    paths:
      /api/messages:
        get:
          operationId: get-messages
          summary: Get messages
          responses:
            '200':
              description: A successful response
              schema:
                type: array
                items:
                  type: string
        post:
          operationId: post-message
          summary: Post message
          parameters:
            - in: body
              name: message
              description: The message to create.
              schema:
                type: object
                properties:
                  message:
                    type: string
                    example: Test message
          responses:
            '200':
              description: A successful response
              schema:
                type: string
      /api/messages/{id}:
        get:
          operationId: get-message
          summary: Get message
          parameters:
            - in: path
              name: id
              type: string
              required: true
              description: id of message to get
          responses:
            '200':
              description: A successful response
              schema:
                type: string
        delete:
          operationId: delete-message
          summary: Delete message
          parameters:
            - in: path
              name: id
              type: string
              required: true
              description: id of message to get
          responses:
            '200':
              description: A successful response
              schema:
                type: string
  EOF
  
  depends_on  = [google_cloud_run_service.api]
}
