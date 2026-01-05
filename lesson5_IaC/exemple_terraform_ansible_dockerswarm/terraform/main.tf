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

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ouvre le port HTTP au monde
  }

  # autoriser le trafic entrant sur le port 22 (SSH) uniquement pour l'adresse IP de l'utilisateur, pour Ansible
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"] 
  }

  # Ports Docker Swarm (entre les membres du groupe: self=true)
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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