#!/bin/bash

# créer et publier l'image docker de l'app
.. && docker build -t hibanaj/multiverse:v1 .
docker push votre-pseudo/multiverse:v1

# créer l'infrastructure
cd ../terraform
terraform init
terraform apply -auto-approve

# configurer avec Ansible
echo "Attente de 30s pour le démarrage des instances..."
sleep 30
cd ../ansible
ansible-playbook -i inventory.ini playbook.yml --private-key=./ma-cle.pem