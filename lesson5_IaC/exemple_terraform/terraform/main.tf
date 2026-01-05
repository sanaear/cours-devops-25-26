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

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id 

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id 
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id 
  route_table_id = aws_route_table.public_rt.id
}

# --- SÉCURITÉ ---
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  # autoriser le trafic entrant sur le port 80 (HTTP) depuis n'importe où sur Internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ouvre le port HTTP au monde
  }

  # autoriser le trafic entrant sur le port 22 (SSH) uniquement pour l'adresse IP de l'utilisateur
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"] 
  }

  # autoriser tout le trafic sortant de l'instance vers n'importe quelle destination (permet de télécharger des paquets)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- SERVEUR ---
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 (Irlande)
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "ma-cle-ssh" # Indispensable pour SSH

  # copie du dossier local "app" vers le serveur
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${path.module}/ma-cle.pem")
    host        = self.public_ip
  }
  provisioner "file" {
    source      = "../app/"
    destination = "/tmp/app"
  }

  # installation et déploiement
  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              # On déplace les fichiers du dossier temporaire vers le dossier web
              cp -r /tmp/app/* /var/www/html/
              chown -R apache:apache /var/www/html/
              EOF
}