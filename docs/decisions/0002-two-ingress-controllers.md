# ADR 0002: Two Ingress Controllers (Traefik + NGINX)

## Status
Accepted

## Context
The platform needs to route HTTP/HTTPS traffic to various services. These services fall into two distinct categories:
1. **Internal/Administrative UI:** Dashboards meant for platform operators and developers (ArgoCD UI, Grafana, n8n editor).
2. **User-Facing Applications:** End-user interfaces for interacting with AI (Open WebUI, Flowise).

Different Ingress controllers have different strengths.
- **Traefik** is excellent for internal routing. It provides native `IngressRoute` CRDs, built-in middleware for features like BasicAuth, and a useful diagnostic dashboard.
- **NGINX Ingress** is the industry standard for external routing. It possesses a mature and vast ecosystem of annotations, making it highly compatible with future integrations like Web Application Firewalls (WAF) or external authentication providers (e.g., OAuth2 Proxy).

## Decision
We will deploy **Two Ingress Controllers**: Traefik and NGINX Ingress.

- **Traefik** will handle routing for internal, administrative, and developer-focused tools.
- **NGINX Ingress** will handle routing for user-facing product applications.

Each controller will be assigned a distinct external IP address via MetalLB from the configured IP pool.
Both controllers will utilize a shared `cert-manager` ClusterIssuer to handle TLS certificate provisioning.

## Consequences
**Positive:**
- Clear separation of internal vs external traffic flows.
- Ability to utilize Traefik's middlewares for quick administrative protections (BasicAuth) without polluting user-facing configurations.
- NGINX is positioned for future enterprise-grade user-facing security enhancements.

**Negative:**
- Consumes two IP addresses from the MetalLB pool instead of one.
- Requires managing two different configuration paradigms (`IngressRoute` vs standard `Ingress` with annotations).
- Slightly increased CPU/Memory overhead on the cluster.
