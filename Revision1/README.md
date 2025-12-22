# Exercice de révision


## Configurations git préliminaire

1. Ouvrir localement une fenêtre git bash
2. Automatiser le changement par git entre les fins de lignes LF et CRLF.
3. Changer le nom par défaut de la branche principale git de "master" à "main"

```powershell
git config --global core.autocrlf true
git config --global init.defaultBranch main
```

## A. Télécharger les fichiers de l'application localement
1. Sur le site [HTML5Up](https://html5up.net), téléchargez l'application **Multiverse**.  
2. Extraire les fichiers et les mettre dans un dossier nommé `GalleryApp`.

Il existe d'autres sites similaires, contenant plusieurs modèles de site en HTML:
- [https://templatesjungle.com](https://templatesjungle.com)
- [https://technext.github.io/100-template-bundle/](https://technext.github.io/100-template-bundle/)
- [https://website-templates.github.io](https://website-templates.github.io)

## B. Initier git et sauvegarder
1. Créer et remplir un fichier `.gitattributes` (ou copier [ce fichier](https://github.com/hibanajjar998/articlesapp_ctrl1/blob/main/.gitattributes))
2. Ouvrir git à l'intérieur du dossier créé,
2. Initier git, Ajouter tous les documents, Sauvegarder (commit).


```powershell
cd ...\GalleryApp
notepad .gitattributes  # à remplir
git init
git add .
git commit -m "initial commit"
```

## C. Créer un dépôt distant GitHub, pousser l'application
1. Sur le site GitHub, créer un nouveau répositoire, en mode public,
2. Y pousser le dossier créé localement.

```powershell
git remote add origin <lien_ssh_de_votre_repositoire>
git branch -M main
git push -u origin main
```

## D. Localement, lancer l'app dans un conteneur Docker
1. créer le Dockerfile (basé sur nginx ([doc](https://hub.docker.com/_/nginx)))
2. construire l'image
3. la lancer dans un conteneur
4. ouvrir l'application au localhost
5. arrêter le conteneur puis supprimer l'image

```Dockerfile
# ./Dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
```


```powershell
# cmd
docker build -t multiverse_app .
docker run --name multiverse_c -p 8080:80 -d multiverse_app

docker rm multiverse_c
docker rmi multiverse_app
```


### Information importante dans la [documentation nginx](https://hub.docker.com/_/nginx):
- Image par défaut: nginx:latest
- Version plus petite, Alpine: nginx:alpine 
- Racine Web par défaut : /usr/share/nginx/html
- Port par défaut : 80 

### Autres alternatives:

- Apache (httpd), ([doc](https://hub.docker.com/_/httpd))
```Dockerfile
FROM httpd:alpine
COPY . /usr/local/apache2/htdocs/
EXPOSE 80
```

- Python (http.server), ([doc](https://hub.docker.com/_/python))
```Dockerfile
FROM python:slim
WORKDIR /app
COPY . .
EXPOSE 8000
CMD ["python", "-m", "http.server", "8000"]
```

## E. Créer localement une branche des tests

1. Créer et basculer vers une branche `tests`
2. Ajouter les fichiers nécessaires de tests de qualité de code et tests unitaires

### Tests de Qualité de Code, de Syntaxe (Linting)
- **HTMLHint** : vérifie les balises HTML sont bien fermées et respectent les standards.
- **Stylelint** : pour les dossiers sass et css (feuilles de style).
- **ESLint** : pour les fichiers dans le dossier js (JavaScript).

### Tests Unitaires
- **Jest** : teste une fonction isolée dans assets/js.

## F. Lancer les tests avant de créer l'image Docker
1. modifier le `Dockerfile` pour d'abord lancer les tests avant de construire l'image
2. fixer les erreurs (`--fix`)
3. initier un conteneur pour vérifier que votre application web fonctionne toujours bien
4. supprimer le conteneur, puis l'image

```Dockerfile
# Dockerfile modifié
FROM node:slim AS build-stage
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run lint
RUN npm run test

FROM nginx:alpine
COPY --from=build-stage /app /usr/share/nginx/html
EXPOSE 80
```

```powershell
docker run 
```

## G. Récupérer le fichier `package-lock.json`
1. créer une image qui s'arrête au premier stage (`--target build-stage`)
2. initier un conteneur de cette image
2. copier le fichier `/app/package-lock.json` généré dans le conteneur vers le dossier local de l'app
3. arrêter le conteneur puis supprimer l'image.
4. pousser ce fichier vers le répositoire distant

```powershell
# récupérer le fichier
docker build --target build-stage -t mv_app_tmp .
docker run --name tmp_c mv_app_tmp
docker cp tmp_c:/app/package-lock.json ./package-lock.json
docker rm tmp_c
docker rmi mv_app_tmp

# le pousser vers le répo distant
git add package-lock.json
git commit -m "add package-lock generated in docker container"
git push origin main
```


## H. Fusionner avec la branche 'main'
1. Basculer vers la branche 'main'
2. Fusionner la branche 'tests'
3. supprimer la branche 'tests'
4. pousser vos nouvelles modifications vers le répositoire distant

```powershell
git checkout main
git merge tests
git branch -d tests
git push origin main
```

**!!** Lors du travail dans un répositoire avec plusieurs collaborateurs, il se peut que quelqu'un ait changé la branche `main` du répositoire distant (partagé) pendant que vous travailliez localement ur votre branche `tests`. Dans ce cas, pour rester à jour, il est important de d'abord tirer les modifications dans la branhce `main` depuis le répositoire distant, avant d'y fusionner la branche `tests`:
```powershell
git pull origin main
```

## I. Écrire le workflow GitHub
1. créer un fichier `.github/workflows/ci_test_build.yml`
2. y créer un job pour les tests, 
3. y ajouter un job qui dépend du premier, et qui construit l'image et la pousse au GHCR
4. déclencher le job, débugger


## J. Déployer localement un docker swarm
 1. Créer un fichier `docker-compose.yml` contenant un seul service, et y configurer le déploiement
 2. créer un swarm docker et le déployer
 3. mettre à l'echelle en augmentant le nombre de réplicas
 4. arrêter le swarm.

```YAML
# ./docker-compose yml
services:
  web:
    # Remplacez par l'image sur GHCR si vous voulez tester l'image distante
    # ou utilisez l'image locale 
    image: multiverse-app:latest
    ports:
      - "8080:80"
    deploy:
      replicas: 3
      restart_policy:
        condition: any
      resources:
        limits:
          cpus: '0.2'  # 20% d'un seul coeur CPU
          memory: 64Mo  # quand dépassé, OOM Kill
```


```powershell
### initier et dployer ------------
docker swarm init
docker stack deploy -c docker-compose.yml multiverse_swarm

### visualiser --------------------
docker stack ls	#Liste les applications déployées.
docker service ls	#Affiche l'état des services (vérifie si les 2 replicas sont prêts).
docker service ps multiverse_swarm_web	# Montre sur quel "nœud" tourne chaque replica.
docker stats  # Affiche l'utilisation des resources en temps réel

### mettre à l'echelle (scaling) ----
docker service scale multiverse_swarm_web=5

### arrêter -------------------------
docker stack rm multiverse_swarm	#Arrête et supprime tout le déploiement.
```
