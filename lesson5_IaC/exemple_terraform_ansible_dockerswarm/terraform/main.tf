# Ressources principales de l'infrastructure

# --- RÉSEAU ---
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr 
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" } 
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id 
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true # IP publique obligatoire pour le web
  tags = { Name = "${var.project_name}-public-subnet" } 
}



# --- SÉCURITÉ ---
resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ouvre le port HTTP au monde
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Autorisation supplémentaire pour Swarm entre les noeuds
resource "aws_security_group_rule" "swarm_internal" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true # Les noeuds se parlent entre eux
  security_group_id = aws_security_group.web_sg.id
}



# --- SERVEUR ---

# manager
resource "aws_instance" "manager" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = "ma-cle-ssh" # à remplacer par votre clé ssh
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = { Name = "swarm-manager", Role = "manager" }
}

# 3 workers
resource "aws_instance" "workers" {
  count         = 3
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = "ma-cle-ssh" # à remplacer par votre clé ssh
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = { Name = "swarm-worker-${count.index}", Role = "worker" }
}

# génération de l'inventaire pour ansible:
# le type local_file ne crée rien sur AWS, mais génère un fichier physique la machine qui exécute Terraform (ton ordinateur par exemple), contenue du fichier défini par: content = <<-EOT ... EOT
resource "local_file" "inventory" {
  content = <<-EOT
    [manager]
    ${aws_instance.manager.public_ip} ansible_user=ec2-user

    [workers]
    ${join("\n", aws_instance.workers.*.public_ip)} ansible_user=ec2-user
  EOT
  filename = "../ansible/inventory.ini"
}