# modules/acm/variables.tf

variable "project_name" {
  description = "Project name (used for tagging and resource naming)."
  type        = string
}

variable "environment" {
  description = "Deployment environment (used for tagging and resource naming)."
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "domain_name" {
  description = "The primary domain name for the certificate (e.g., example.com)."
  type        = string
}

variable "subject_alternative_names" {
  description = "A list of Subject Alternative Names (SANs) for the certificate (e.g., [\"www.example.com\", \"api.example.com\"])."
  type        = list(string)
  default     = []
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare Zone ID where the domain is managed."
  type        = string
}
