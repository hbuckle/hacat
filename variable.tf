variable "access_key" {
  type = "string"
}

variable "secret_key" {
  type = "string"
}

variable "region" {
  default     = "eu-west-1"
  type        = "string"
  description = "Region. Must be enabled for SMS alerts"
}

variable "pager" {
  type        = "string"
  description = "Mobile number to send ELF health alerts to"
}
