# Creando la zona dns
resource "google_dns_managed_zone" "parent_zone" {
#  provider = "google-beta"
  name        = "arp-zona"
  dns_name    = "arp-zona.proyecto-asir.com."
  description = "Zona DNS del proyecto asir"
}

#Añadiendo el registro a la zona dns
resource "google_dns_record_set" "calcetines_dns" {
#  provider = "google-beta"
  managed_zone = google_dns_managed_zone.parent_zone.name
  name         = "calcetines.arp-zona.proyecto-asir.com."
  type         = "A"
  rrdatas      = ["34.77.9.88"]
  ttl          = 86400
}