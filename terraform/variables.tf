variable "location" {
  description = "Région Azure de déploiement"
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Nom du resource group"
  type        = string
  default     = "rg-cowrie-honeypot"
}

variable "admin_username" {
  description = "Utilisateur admin des VM"
  type        = string
  default     = "azadmin"
}

variable "admin_ip_cidr" {
  description = "IP publique (format CIDR, ex: x.x.x.x/32) autorisée pour le SSH admin et le dashboard Wazuh. A définir dans un terraform.tfvars non versionné."
  type        = string
}