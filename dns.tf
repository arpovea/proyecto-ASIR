# # Creando la zona dns
# resource "google_dns_managed_zone" "parent_zone" {
#   #  provider = "google-beta"
#   name        = "arp-zona"
#   dns_name    = "arp-zona.proyecto-asir.com."
#   description = "Zona DNS del proyecto asir"
# }

# #Añadiendo el registro a la zona dns calcetines
# resource "google_dns_record_set" "calcetines_dns" {
#   #  provider = "google-beta"
#   managed_zone = google_dns_managed_zone.parent_zone.name
#   name         = "calcetines.arp-zona.proyecto-asir.com."
#   type         = "A"
#   rrdatas      = [google_compute_address.ipv4_1.address]
#   ttl          = 86400
#   depends_on = [
#   helm_release.helm_ingress_controler_herramientas
# ]
# }

# #Añadiendo el registro a la zona dns argocd 
# resource "google_dns_record_set" "argocd_dns" {
#   #  provider = "google-beta"
#   managed_zone = google_dns_managed_zone.parent_zone.name
#   name         = "argocd.arp-zona.proyecto-asir.com."
#   type         = "A"
#   rrdatas      = [google_compute_address.ipv4_2.address]
#   ttl          = 86400
#   depends_on = [
#     helm_release.helm_ingress_controler_herramientas
#   ]
# }