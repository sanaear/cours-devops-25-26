# Déclaration de toutes les variables

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "Région AWS"
  type        = string
}

variable "vpc_cidr" {
  description = "Plage IP du réseau"
  type        = string
}

variable "public_subnet_cidr" {
  description = "Plage IP du sous-réseau"
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
}

variable "worker_count" {
  description = "Nombre de noeuds workers"
  type        = number
}
