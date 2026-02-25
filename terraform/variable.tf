variable "region" {
  default = "ap-south-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {
  default = "jenkins-mum1"
}

# -------- RDS Variables --------

variable "db_username" {
  description = "Database username"
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  sensitive   = true
}
