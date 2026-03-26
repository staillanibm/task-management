# Exposer le Registry OpenShift

## Méthode 1: Utiliser la commande oc (Recommandé)

### Exposer le registry

```bash
# Exposer le registry avec une route par défaut
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

### Obtenir l'URL du registry

```bash
# Récupérer l'hostname de la route
export REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
echo $REGISTRY_HOST
```

### Se connecter au registry

```bash
# Se connecter avec votre token OpenShift
oc whoami -t | docker login -u $(oc whoami) --password-stdin $REGISTRY_HOST
```

## Méthode 2: Créer une Route manuellement

Si la méthode 1 ne fonctionne pas, créez une route manuellement:

```bash
oc create route reencrypt --service=image-registry -n openshift-image-registry
```

Puis récupérez l'URL:

```bash
export REGISTRY_HOST=$(oc get route image-registry -n openshift-image-registry -o jsonpath='{.spec.host}')
```

## Construire et Pousser l'Image

### 1. Tag l'image

```bash
# Depuis le répertoire du projet
docker build -t task-management-api:latest .

# Tag avec l'URL du registry OpenShift
docker tag task-management-api:latest $REGISTRY_HOST/task-management/task-api:latest
```

### 2. Push vers OpenShift

```bash
docker push $REGISTRY_HOST/task-management/task-api:latest
```

## Utiliser l'Image dans le Deployment

Mettez à jour `deployment.yaml`:

```yaml
spec:
  containers:
  - name: task-api
    image: image-registry.openshift-image-registry.svc:5000/task-management/task-api:latest
```

Ou avec l'URL externe (si vous poussez depuis l'extérieur):

```yaml
spec:
  containers:
  - name: task-api
    image: default-route-openshift-image-registry.apps.your-cluster.com/task-management/task-api:latest
```

## Alternative: Build directement dans OpenShift

### Créer un BuildConfig

```bash
# Créer le namespace d'abord
oc create namespace task-management

# Créer un nouveau build depuis le Dockerfile
oc new-build --name=task-api --binary --strategy=docker -n task-management

# Pousser le code source
oc start-build task-api --from-dir=. --follow -n task-management
```

### Utiliser l'image construite

L'image sera disponible à:
```
image-registry.openshift-image-registry.svc:5000/task-management/task-api:latest
```

## Vérification

```bash
# Lister les images dans votre namespace
oc get imagestream -n task-management

# Voir les détails de l'image
oc describe imagestream task-api -n task-management
```

## Troubleshooting

### Erreur: "x509: certificate signed by unknown authority"

```bash
# Ajouter le certificat comme non sécurisé (développement uniquement)
docker login -u $(oc whoami) -p $(oc whoami -t) $REGISTRY_HOST --tls-verify=false
```

Ou configurez le daemon Docker pour accepter le registry:

```bash
# Ajouter à /etc/docker/daemon.json
{
  "insecure-registries": ["your-registry-host:443"]
}

# Redémarrer Docker
sudo systemctl restart docker
```

### Erreur: "unauthorized: authentication required"

```bash
# Se reconnecter
oc login
oc whoami -t | docker login -u $(oc whoami) --password-stdin $REGISTRY_HOST
```

### Le registry n'est pas exposé

```bash
# Vérifier l'état du registry
oc get configs.imageregistry.operator.openshift.io cluster -o yaml

# Vérifier les routes
oc get routes -n openshift-image-registry
```

## Commandes Utiles

```bash
# Voir tous les ImageStreams
oc get is --all-namespaces

# Importer une image externe
oc import-image task-api --from=docker.io/youruser/task-api:latest --confirm -n task-management

# Créer un ImageStream manuellement
oc create imagestream task-api -n task-management

# Tag une image
oc tag task-api:latest task-api:v1.0.0 -n task-management
```
