#! /bin/bash

# Create directories to persist the data in MongoDB and Redis.
mkdir -p data/{mongo,redis}

# Generar el .env correctamente
SIGNING_SECRET="$(openssl rand -base64 48)"
echo "SIGNING_SECRET=${SIGNING_SECRET}" > .env

# Crear secret desde .env (y si ya existe lo reemplaza)
kubectl create secret generic talk-secret \
  --from-env-file=.env \
  -n talk-ns \
  --dry-run=client -o yaml | kubectl apply -f -

# Aplicar lo manifiestos
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-mongo.yaml
kubectl apply -f 02-redis.yaml
kubectl apply -f 03-talk.yaml

# Consultas
kubectl get pods -n talk
kubectl get svc -n talk
