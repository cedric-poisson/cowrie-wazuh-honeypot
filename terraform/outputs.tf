output "cowrie_public_ip" {
  description = "IP publique du honeypot Cowrie (SSH exposé sur le port 2222)"
  value       = azurerm_public_ip.pip_honeypot.ip_address
}

output "wazuh_public_ip" {
  description = "IP publique du dashboard Wazuh (HTTPS sur le port 443)"
  value       = azurerm_public_ip.pip_wazuh.ip_address
}

output "wazuh_private_ip" {
  description = "IP privée de la VM Wazuh, utilisée par l'agent pour l'enrollment et l'envoi d'événements (reste dans le VNet)"
  value       = azurerm_network_interface.nic_wazuh.private_ip_address
}