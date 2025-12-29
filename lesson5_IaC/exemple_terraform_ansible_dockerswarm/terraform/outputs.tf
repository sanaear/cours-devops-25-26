# Valeurs à afficher après le déploiement

output "manager_ip" {
  description = "IP publique du Manager Swarm"
  value       = aws_instance.manager.public_ip
}

output "workers_ips" {
  description = "IPs publiques des Workers"
  value       = aws_instance.workers[*].public_ip
}

output "ssh_instruction" {
  value = "Connectez-vous avec : ssh -i 'votre-cle.pem' ec2-user@${aws_instance.manager.public_ip}"
}