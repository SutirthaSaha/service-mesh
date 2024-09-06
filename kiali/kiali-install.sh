helm repo add kiali https://kiali.org/helm-charts
# operator install
# helm install --set cr.create=true --set cr.namespace=istio-system --set cr.spec.auth.strategy="anonymous" --namespace kiali-operator --create-namespace kiali-operator kiali/kiali-operator --version 1.81.0

# server install
helm install --namespace istio-system kiali-server kiali/kiali-server --version 1.81.0
