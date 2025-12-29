# Valeurs à afficher après le déploiement

output "vpc_id" {
  value = aws_vpc.main.id 
}

output "website_url" {
  description = "Accédez à votre site ici"
  value       = "http://${aws_instance.web.public_ip}" 
}