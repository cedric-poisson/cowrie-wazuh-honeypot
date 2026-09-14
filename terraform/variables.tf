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