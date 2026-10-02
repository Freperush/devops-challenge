variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "github_owner" {
  type = string
}

variable "github_owner_id" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "github_repository_id" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2as_v4"
}

variable "alert_email" {
  type = string
}

variable "publisher_name" {
  type    = string
  default = "DevOps Challenge"
}

variable "api_key" {
  type      = string
  sensitive = true
  default   = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
  default = {
    project     = "devops-technical-challenge"
    environment = "shared"
    managed-by  = "terraform"
    purpose     = "technical-assessment"
    cost-center = "personal"
    owner       = "candidate"
  }
}
