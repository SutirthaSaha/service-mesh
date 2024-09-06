## Summary
For enabling authentication for the CLD service for the CLD-LIS plugin, we chose the approach of installing service-mesh which provides a feature to provide service-to-service authentication ensuring that no external service or unauthorized agent can access the service.
## Motivation
In the security concept for the plugin, it was suggested that we have to enable authentication for the CAP service which was consuming the HANA DB to ensure that there aren't any invalid requests loading their system.

## Detailed Design

### Analysis
On analysing the problem at hand there were 3 possible solutions:
    
    1. Implement the authentication in the CAP service and ensure the services communicating to pass the required parameters to verify.
    2. Using the existing common authentication module that we have for the SLIs v2 and CLDIS service.
    3. Using service mesh for handling service-to-service authentication within the services.

Let's go through each of the solution once and check which one would be the one we can go forward with.

  1. **Authentication within the CAP application** 
CAP applicaition supports multiple authentication mechanisms but all of them need some implementation on both the service as well as the synchronizer side.
  2. **Authentication using Common Authentication Module**
The common authenticaiton module was built as the interceptor for all the requests and verify whether they have proper authentications. But the catch here is that the module is responsible to extract the customer scope from the token being passed(XSUAA, OIDC, Self-Signed) and forward the same in the header. 
In this case we would query both the master data as well as the customer scoped data. For such queries it would be unnecessary to authenticate the request using the module as along with authentication it also does more than that and both the servie and the synchronizer would have to adapt to the same.
  3. **Service Mesh**
Service-to-service authentication within a service-mesh is facilitated using mTLS where each service is issued a digital certificate. The sidecar-proxies take care of presenting as well as verifying the certificates without requireing the services to manage the complexities of the authentication process explicitly.

#### Analysis Result
On analysing the options we decided that service-mesh was the option we want to go ahead with as it provided us with more features as well as abstracts the security concerns from the individual service - reducing the custom implementations and the complexities that it brings along.

### Working
Step by step flow request from a pod to a service with Istio proxy enabled:
- A pod equipped with an Istio sidecar proxy sends an outgoing request to communicate with another service that also has Istio enabled. The application container within the pod transmits the request, which is intercepted by the pod's local Istio sidecar proxy. This interception is a result of the networking rules applied by Istio, which directs traffic through the sidecar.
- The Istio sidecar proxy queries the Istio control plane to resolve the location of the target service. It relies on service registry information to determine the current available endpoints of the service. Once an endpoint is selected based on routing rules and load balancing configurations, the sidecar proxy validates the request against the current access control and traffic policies as dictated by the control plane.
- If mutual TLS is enabled, the sidecar proxy initiates a TLS handshake with the target service's sidecar proxy. The handshake involves an exchange of certificates that are validated against Istio's Certificate Authority, confirming the identity of both sides. Upon successful mutual authentication and establishment of a secure channel, the sidecar proxy forwards the request to the target service's sidecar proxy.
- Upon receipt, the target service's sidecar proxy decrypts the request and passes it to the application container within its pod. The application processes the request and sends a response back to its sidecar proxy. The response is then encrypted and sent over the established secure channel to the originating pod's sidecar proxy.
- The originating pod's sidecar proxy receives the encrypted response, decrypts it, and forwards it to the application container within the pod. The application container processes the received response, completing the cycle of communication.

![](../images/rfc-0012/service-mesh-1.png)

### Enabling mTLS
A PeerAuthentication resource is defined by the user and applied to a specific namespace, a specific service, or globally across the entire mesh. This resource dictates the mTLS mode that should be used and can be set to STRICT, PERMISSIVE, or DISABLED.

#### mTLS Modes:
- **STRICT**: In this mode, the sidecar proxies enforce that all incoming connections use mTLS. This means that any service without a valid certificate will not be able to establish a connection.
- **PERMISSIVE**: This mode allows a service to accept both mTLS and plain-text traffic. This is useful for gradually migrating services to mTLS or for services that need to communicate with external clients that do not support mTLS.
- **DISABLED**: This mode disables mTLS for the specified targets, allowing only plain-text traffic. It's not recommended for production environments where security is a concern.

Here's an example of a PeerAuthentication policy that enables mTLS in STRICT mode for all workloads in the `demo` namespace:
```
apiVersion: security.istio.io/v1beta1  
kind: PeerAuthentication  
metadata:  
  name: default  
  namespace: `demo` 
spec:  
  mtls:  
    mode: STRICT
```

![](../images/rfc-0012/service-mesh-2.png)

## Points for the future
- Utilizing the capabilities of the mesh more, having it enabled for rest of the modules of SLIs.
- Move out of the current setup of having NGINX as the gateway and Envoy as the edge-proxy and move to Istio Gateway.

## References
- Installing using helm: https://istio.io/latest/docs/setup/install/helm/
- Sidecar Issues faced: 
  - https://github.com/istio/istio/issues/33911
  - https://stackoverflow.com/questions/54921054/terminate-istio-sidecar-istio-proxy-for-a-kubernetes-job-cronjob
- mTLS service-to-service secure communication blog: https://istio.io/latest/blog/2023/secure-apps-with-istio/
