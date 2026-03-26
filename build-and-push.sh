#!/bin/bash

# Script pour construire et pousser l'image vers le registry OpenShift

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=================================="
echo "Build & Push to OpenShift Registry"
echo "=================================="
echo ""

# Vérifier que oc est installé
if ! command -v oc &> /dev/null; then
    echo -e "${RED}✗${NC} oc CLI not found. Please install it first."
    exit 1
fi

# Vérifier que docker est installé
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗${NC} docker not found. Please install it first."
    exit 1
fi

# Vérifier que l'utilisateur est connecté
if ! oc whoami &> /dev/null; then
    echo -e "${RED}✗${NC} Not logged in to OpenShift. Please run: oc login"
    exit 1
fi

echo -e "${GREEN}✓${NC} Logged in as: $(oc whoami)"
echo ""

# Exposer le registry si nécessaire
echo "1. Checking registry exposure..."
if ! oc get route default-route -n openshift-image-registry &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Registry not exposed. Exposing it..."
    oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
    echo "Waiting for route to be created..."
    sleep 10
fi

REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)

if [ -z "$REGISTRY_HOST" ]; then
    echo -e "${RED}✗${NC} Could not get registry host"
    exit 1
fi

echo -e "${GREEN}✓${NC} Registry host: $REGISTRY_HOST"
echo ""

# Login to registry
echo "2. Logging in to OpenShift registry..."
TOKEN=$(oc whoami -t)
echo $TOKEN | docker login -u $(oc whoami) --password-stdin $REGISTRY_HOST 2>&1 | grep -v "WARNING"
echo -e "${GREEN}✓${NC} Logged in to registry"
echo ""

# Créer le namespace si nécessaire
echo "3. Checking namespace..."
if ! oc get namespace task-management &> /dev/null; then
    echo "Creating namespace task-management..."
    oc create namespace task-management
fi
echo -e "${GREEN}✓${NC} Namespace ready"
echo ""

# Build l'image
echo "4. Building Docker image..."
IMAGE_NAME="task-management-api"
IMAGE_TAG="latest"
FULL_IMAGE="$REGISTRY_HOST/task-management/$IMAGE_NAME:$IMAGE_TAG"

docker build -t $IMAGE_NAME:$IMAGE_TAG .
echo -e "${GREEN}✓${NC} Image built"
echo ""

# Tag l'image
echo "5. Tagging image..."
docker tag $IMAGE_NAME:$IMAGE_TAG $FULL_IMAGE
echo -e "${GREEN}✓${NC} Image tagged as: $FULL_IMAGE"
echo ""

# Push l'image
echo "6. Pushing image to OpenShift registry..."
docker push $FULL_IMAGE
echo -e "${GREEN}✓${NC} Image pushed"
echo ""

# Vérifier l'ImageStream
echo "7. Verifying ImageStream..."
sleep 2
if oc get imagestream $IMAGE_NAME -n task-management &> /dev/null; then
    echo -e "${GREEN}✓${NC} ImageStream created"
    oc get imagestream $IMAGE_NAME -n task-management
else
    echo -e "${YELLOW}⚠${NC} ImageStream not found, it may take a moment to appear"
fi
echo ""

echo "=================================="
echo "Build & Push Complete!"
echo "=================================="
echo ""
echo "Image available at:"
echo "  External: $FULL_IMAGE"
echo "  Internal: image-registry.openshift-image-registry.svc:5000/task-management/$IMAGE_NAME:$IMAGE_TAG"
echo ""
echo "To use this image in your deployment, update deployment.yaml:"
echo "  image: image-registry.openshift-image-registry.svc:5000/task-management/$IMAGE_NAME:$IMAGE_TAG"
echo ""
echo "Then deploy:"
echo "  cd k8s && oc apply -f ."
