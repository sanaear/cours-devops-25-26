
## Sommaire

1.  [Exemple 1: Terraform](#exemple-1-eléments-du-fichier-maintf-dans-lexemple-terraform)
    * [1. Différence entre VPC et Subnet](#1-différence-entre-vpc-et-subnet)
    * [2. CIDR: C'est quoi ?](#2-cidr-c-est-quoi)
    * [3. Niveaux de segmentation du VPC](#3-niveaux-de-segmentation-du-vpc)
    * [4. Qu'est-ce qui rend un sous-réseau "Public" ?](#4-quest-ce-qui-rend-un-sous-réseau-public-)
    * [5. Rôle des adresses IP privées et publiques](#5-rôle-des-adresses-ip-privées-et-publiques)
    * [6. Rôle de la table de routage ajoutée](#6-rôle-de-la-table-de-routage-ajoutée)
    * [7. Rôle du Groupe de Sécurité (Security Group)](#7-rôle-du-groupe-de-sécurité-security-group)
    * [8. Rôle de checkip.amazonaws.com et chomp()](#8-rôle-de-checkipamazonawscom-et-de-la-fonction-chomp)
    * [9. La clé SSH : utilité, obtention et chemin](#9-la-clé-ssh--utilité-obtention-et-chemin)
    * [10. Quand le script user_data est-il exécuté ?](#10-quand-le-script-user_data-est-il-exécuté-)
2.  [Exemple 2: Terraform + Ansible + DockerSwarm](#exemple-2-eléments-des-fichiers-maintf-et-playbookyml-dans-lexemple-terraformansibledockerswarm)
    * [1. Communication entre les noeuds](#1-communication-entre-les-noeuds)
    * [2. L'option count = 3](#2-loption-count--3)
    * [3. La ressource local_file](#3-la-ressource-local_file)
    * [4. Le fichier inventory.ini](#4-le-fichier-inventoryini)
    * [5. Paramètres du Playbook Ansible](#5-paramètres-du-playbook-ansible)
    * [6. L'option --advertise-addr](#6-loption---advertise-addr)
    * [7. La commande docker swarm join-token worker -q](#7-la-commande-docker-swarm-join-token-worker--q)
    * [8. Syntaxe hostvars[groups['manager'][0]]](#8-syntaxe-hostvarsgroupsmanager0)
    * [9. Qu'est-ce que ec2-user ?](#9-quest-ce-que-ec2-user-)
    * [10. La commande ansible-playbook](#10-la-commande-ansible-playbook)


## Exemple 1: Eléments du fichier `main.tf` dans l'exemple Terraform:

### 1. Différence entre VPC et Subnet

Le **VPC (Virtual Private Cloud)** est le réseau privé isolé global dans le cloud AWS. Le **Subnet (Sous-réseau)** est une subdivision de ce VPC. Lorsqu'on crée des ressources (par exemple `resource "aws_instance" ..`), on ne déploie pas l'instance directement dans un VPC, mais elle doit plutôt résider dans un subnet.

### 2. CIDR : C'est quoi ?

Le **CIDR (Classless Inter-Domain Routing)** est la plage d'adresses IP allouée au réseau (VPC ou Subnet). Par exemple, `10.0.0.0/16` définit le nombre d'adresses disponibles pour l'ensemble de votre infrastructure. `10.0.0.0` continet quatres blocs de 8 bits chacun, et donc chaque bloc prend des valeurs entre 0 et 255. `/16` indique que les 16 premiers bits sont fixés (en commençant par la gauche). Cela laisse 16 bits pour les adresses d'appareils, soit $2^{16} = 65\,536$ adresses IP possibles.

Le sous-réseau public (dans le fichier [main.tf](exemple_terraform/terraform/main.tf)) utilise `10.0.1.0/24` : cela signifie que ce subnet est une petite "découpe" à l'intérieur du VPC (`10.0.0.0/16`, come définit dans le fichier [terraform.tfvars](exemple_terraform/terraform/terraform.tfvars)).

Le `/24` fixe les trois premiers blocs et donc limite ce sous-réseau à 256 adresses (de `10.0.1.0` à `10.0.1.255`), ce qui est largement suffisant pour les instances EC2.

### 3. Niveaux de segmentation du VPC

On segmente le VPC en différents subnets (sous-réseaux) pour organiser et sécuriser l'architecture suivants différentes considérations :

* **Public/Privé :** pour isoler les ressources exposées (Web) de celles sensibles (Bases de données).
* **Étage :** Séparer la couche Présentation, Application et Data.
* **Environnement :** pour distinguer le réseau de Production de celui de Développement et Staging.

### 4. Qu'est-ce qui rend un sous-réseau "Public" ?

Deux éléments doivent être assurés:

1. **Internet Gateway (IGW) :** Le VPC doit posséder une passerelle internet (`resource "aws_internet_gateway" ...`) et le sous-réseau doit avoir une route pointant vers elle (`resource "aws_route_table" ...` et `resource "aws_route_table_association" ...`).


2. **Public IP :** Les instances lancées doivent recevoir une adresse IP publique (activé par `map_public_ip_on_launch = true`, sinon ce paramètre prend par défaut la valeur `false`).


### 5. Rôle des adresses IP privées et publiques

* **IP Publique :** Permet à l'instance d'être jointe depuis l'Internet extérieur (utilisateurs, administrateur via SSH). Cette adresse est attribuée dynamiquement par AWS (en dehors de la plage CIDR).

* **IP Privée :** Permet la communication interne et sécurisée entre les ressources du VPC (ex: le serveur web parle à la base de données) sans passer par internet. **Attention**,  la plage CIDR définie dans le VPC et Subnet concerne exclusivement les adresses IP privées internes au réseau AWS.


### 6. Rôle de la table de routage ajoutée

On a créé une Internet Gateway, mais ceci n'est pas suffisant pour connecter notre instance (serveur) à internet. Il faut créer une table de routage associée au VPC (`resource "aws_route_table" ...`) et y ajouter une route pointant tout le trafic (0.0.0.0/0) vers l'Internet Gateway, ensuite associer cette table de routage à notre sous-réseau public (`resource "aws_route_table_association" ...`).


### 7. Rôle du Groupe de Sécurité (Security Group)

C'est un **pare-feu virtuel** qui contrôle le trafic entrant (ingress) et sortant (egress) au niveau de l'instance. Il bloque tout par défaut, donc on doit explicitement autoriser les ports (80 pour le Web, 22 pour le SSH) et les sources (IP spécifiques ou tout le monde (`0.0.0.0/0`)).


### 8. Rôle de [checkip.amazonaws.com](checkip.amazonaws.com) et de la fonction `chomp()`

* **[checkip.amazonaws.com](checkip.amazonaws.com)** est un service externe qui renvoie l'IP publique de l'ordinateur au moment où on lance Terraform. Cela permet au bloc `data "http" ...` de récupérer automatiquement notre adresse IP et lui autoriser l'accès ssh au sécurity groupe (ingress).  
* **`chomp()`** est une fonction qui supprime le saut de ligne "\n" invisible à la fin de la réponse du site, pour que seule l'adresse IP soit utilisée dans la configuration ingress du groupe de sécurité.


### 9. La clé SSH : utilité, obtention et chemin

* Elle sert de preuve d'identité pour se connecter au serveur (instance) de manière sécurisée sans mot de passe.
* La clé se crée dans la console AWS car c'est Amazon qui doit "connaître" la partie publique de votre clé pour l'autoriser sur vos futurs serveurs. Pour la configurer on lui donne un nom (dans [main.tf](exemple_terraform/terraform/main.tf) on a utilisé le nom "ma-cle-ssh", donc c'est celui qu'on doit indiquer dans la console AWS), on choisit le type RSA et le format `.pem`.
* Pour l'utiliser dans la configuration Terraform, elle doit être accessible localement. Le code `file("${path.module}/ma-cle.pem")` indique qu'elle se trouve dans le même dossier que votre fichier `main.tf`.


### 10. Quand le script user_data est-il exécuté ?

Il est exécuté lors du premier démarrage (boot) de l'instance, une seule fois, lorsqu'on crée l'infrastructure par la commande `terraform apply`. Il sert à l'installation automatique des logiciels (comme Apache) et à la configuration initiale du serveur.



## Exemple 2: Eléments des fichiers `main.tf` et `playbook.yml` dans l'exemple Terraform+Ansible+DockerSwarm:


### 1. Communication entre les noeuds

La communication entre les noeuds est permise par le bloc `ingress` à l'intérieur de `resource "aws_security_group" ...` qui ouvre l'intégralité de la plage du port TCP, c.à.d de `0` à `65535`.  
La condition `self = true` indique que ce bloc ingress et cette ouverture de tous les ports s'applique uniquement entre les ressources qui partagent ce même Security Group.   
Donc, le manager et les workers peurront communiquer librement sur tous les ports nécessaires à Docker Swarm, tout en restant isolés de l'extérieur.



### 2. L'option `count = 3`

Dans la ressource `aws_instance "workers"`, l'argument `count = 3` demande à Terraform de créer **trois instances EC2 identiques**. Au lieu d'écrire trois blocs de code différents, Terraform utilise cette option pour déployer parallèlement les 3 serveurs/noeuds workers.


### 3. La ressource `local_file`

La ressource `local_file "inventory"` ne crée aucun composant sur le cloud AWS, mais elle crée plutôt un fichier texte localement sur notre machine où on exécute Terraform. Elle utilise les données dynamiques d'AWS (comme les adresses IP des serveurs fraîchement créées par les blocs `resource "aws_instance" ...`) pour écrire un fichier utilisable immédiatement par un autre outil, ici Ansible.


### 4. Le fichier `inventory.ini`

Il contient les adresses IP publiques des instances/noeuds/serveurs EC2, classées sous des entêtes de groupes (`[manager]` et `[workers]`), ainsi que l'utilisateur de connexion SSH.
Ce fichier permet à Ansible de savoir sur quels serveurs se connecter pour appliquer les bonnes configurations de Docker Swarm (init, join, stack deploy).
La fcihier [ansible/inventory.ini](./exemple_terraform_ansible_dockerswarm/ansible/inventory.ini) contient des adresses IP fictifs, il sert uniquement d'exemple.


### 5. Paramètres du Playbook Ansible

Ces paramètres définissent la structure d'un "Play" (une étape) ou d'une tâche :

- **hosts**  désigne le groupe de machines (issu de [inventory.ini](./exemple_terraform_ansible_dockerswarm/ansible/inventory.ini)) visé par les instructions.
- **become: yes** active le mode "sudo" pour exécuter les commandes avec les permissions d'administrateur.
- **tasks**  est une liste ordonnée des actions/tâches à exécuter sur les serveurs. Chaque tâche doit commencer par **`- name:`** (qui sert à décrire l'action de manière lisible) et contient **le nom du module utilisé** (comme `shell`, `user` ou `copy`).
- **vars**  définit des variables locales pour stocker des données réutilisables dans les tâches.
- **register**  capture et stocke le résultat d'une commande dans une variable pour un usage futur. Dans le fichier [playbook.yml](./exemple_terraform_ansible_dockerswarm/ansible/playbook.yml), `registre` capture la sortie de la commande `docker swarm join-token worker -q`
et la stocke dans la variable `swarm_token`. Attention, Ansible ne stocke pas seulement la réponse de la commande mais crée un dictionnaire qui contient d'autres d'informations: si la commande a réussi ou non, son temps d'exécution, les erreurs éventuelles (`stderr`), et le texte brut renvoyé par la commande (`stdout`).



### 6. L'option `--advertise-addr`

L'option `--advertise-addr {{ ansible_default_ipv4.address }}` qui suit la commande `docker swarm init` spécifie au manager quelle adresse IP il doit diffuser aux autres noeuds du cluster. 
- La variable Ansible `ansible_default_ipv4.address` contient l'adresse IP privée du host (ici l'instance Manager), et on l'utilise ici pour s'assurer que le manager utilise son adresse IP privée et non publique (qui est dans l'inventaire `inventory.ini`), 
- L'utilisation de l'adresse IP publique pour rejoindre le swarm signifie que le trafic passera par Internet, et cela est lent et coûteux sur AWS, et nécessite d'ouvrir les ports 2377, 7946 et 4789 au monde entier (très dangereux). 
- L'idéal est d'utiliser les adresses IP publiques pour rejoindre le swarm, pour permettre au cluster de communiquer via le réseau local d'AWS, de manière sécurisée et ultra-rapide.


### 7. La commande `docker swarm join-token worker -q`

Elle demande au manager de générer le token permettant à un noeud worker de rejoindre le cluster initié dans le manager.L'option `-q`, "quiet", force Docker à n'afficher que le jeton lui-même, sans phrase d'explication, ce qui permet à Ansible de stocker uniquement le token nécessaire dans la variable `swarm_token`.


### 8. Syntaxe `hostvars[groups['manager'][0]]`

`hostvars[...]` permet d'accède aux variables générées par Ansible ou qu'on a créé dans le playbook(comme le token enregistré précédemment) pour un serveur ou groupe de serveurs spécifique.
`groups['manager']` pointe vers la liste de tous les serveurs dans le groupe "manager". Dans notre exemple on a un seul manager, et le `[0]` le sélectionne (l'indice 0 sélectionne le premier serveur de la liste).  

- `hostvars[groups['manager'][0]]['ansible_default_ipv4.address']` renvoie l'adresse IP privée du serveur manager.
- `hostvars[groups['manager'][0]]['swarm_token'].stdout` renvoie le token généré par le manager pour permettre aux workers de rejoindre le cluster.


### 9. Qu'est-ce que `ec2-user` ?

`ec2-user` est le nom d'utilisateur par défaut créé par Amazon pour les instances/serveurs Linux (AMI Amazon Linux). C'est l'utilisateur distant utilisé par Ansible pour se connecter en SSH et configurer le système.

### 10. La commande `ansible-playbook`

La commande `ansible-playbook -i inventory.ini playbook.yml` dans la dernière ligne du [script/deploy.sh](./exemple_terraform_ansible_dockerswarm/scripts/deploy.sh) permet l'exécution des instructions du [playbook.yml](./exemple_terraform_ansible_dockerswarm/ansible/playbook.yml). Elle nécessite généralement trois paramètres :

1. **`-i inventory.ini`** : Pour spécifier le fichier d'inventaire, c.à.d la liste des serveurs.
2. **`playbook.yml`** : Le fichier contenant les instructions à appliquer.
3. **`--private-key=../terraform/ma-cle.pem`** : indique à Ansible le chemin vers la clé privée SSH (la même clé utilisée par Terraform lors du déploiement des instances EC2).
