# Valeurs spécifiques pour cet environnement
# NE PAS COMMITER si ce fichier contient des secrets!

project_name        = "multiverse-swarm"
environment         = "production"
aws_region          = "eu-west-1"
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
instance_type       = "t2.micro"
worker_count        = 3