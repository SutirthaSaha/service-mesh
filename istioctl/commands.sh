istioctl install -f default-operator.yaml -y
kubectl apply -f ./gateway/01-gateway.yaml
