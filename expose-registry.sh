#!/bin/bash

# Script pour exposer le registry OpenShift vers l'extérieur

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=================================="
echo "Exposer le Registry OpenShift"
echo "=================================="
echo ""

# Vérifier que oc est installé
if ! command -v oc &> /dev/null; then
    echo -e "${RED}✗${NC} oc CLI not found"
    exit 1
fi

# Vérifier que l'utilisateur est connecté
if ! oc whoami &> /dev/null; then
    echo -e "${RED}✗${NC} Not logged in to OpenShift. Run: oc login"
    exit 1
fi

echo -e "${GREEN}✓${NC} Connecté en tant que: $(oc whoami)"
echo ""

# Exposer le registry
echo "1. Exposition du registry..."
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --patch '{"spec":{"defaultRoute":true}}' --type=merge

echo -e "${GREEN}✓${NC} Registry exposé"
echo ""

# Attendre que la route soit créée
echo "2. Attente de la création de la route..."
sleep 5

# Récupérer l'URL
REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)

if [ -z "$REGISTRY_HOST" ]; then
    echo -e "${YELLOW}⚠${NC} Route pas encore disponible, attente..."
    sleep 10
    REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
fi

echo -e "${GREEN}✓${NC} Route créée"
echo ""

# Afficher les informations
echo "=================================="
echo "Registry OpenShift Exposé!"
echo "=================================="
echo ""
echo "URL du registry: $REGISTRY_HOST"
echo ""
echo "Pour vous connecter:"
echo "  oc whoami -t | docker login -u \$(oc whoami) --password-stdin $REGISTRY_HOST"
echo ""
echo "Pour pousser une image:"
echo "  docker tag myimage:latest $REGISTRY_HOST/namespace/myimage:latest"
echo "  docker push $REGISTRY_HOST/namespace/myimage:latest"
echo ""
echo "Pour utiliser le script automatisé:"
echo "  ./build-and-push.sh"
