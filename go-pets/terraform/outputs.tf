output "service_url" {
  value = google_cloud_run_service.go_pets.status[0].url
}