# Déclaration de toutes les variables

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "multiverse-simple" 
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-1" 
}

variable "vpc_cidr" {
  description = "CIDR block pour le VPC"
  type        = string
  default     = "10.0.0.0/16" 
}

variable "instance_type" {
  description = "Puissance de l'instance"
  type        = string
  default     = "t2.micro"
}