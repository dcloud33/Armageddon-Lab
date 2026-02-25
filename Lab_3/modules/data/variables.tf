variable "rds_db_name" {
  type    = string
  default = "labdb"
}

variable "rds_user_name" {
  type    = string
  default = "admin"
}

variable "rds_password" {
  type      = string
  sensitive = true
  default   = "mynewpassword1234!!"
}

variable "user_name" {
  type    = string
  default = "Tokyo_user"
}

variable "saopaulo_vpc_cidr" {
  type = string
  default = "10.70.0.0/16"
}