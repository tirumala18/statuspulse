# Security Documentation

This document outlines the security measures implemented in the StatusPulse project.

## Container Image Scanning

We use Docker multi-stage builds and slim/alpine base images to minimize the attack surface.

**Scanning Tools:**
- **Trivy / Docker Scout:** Image vulnerability scanning should be integrated into the CI/CD pipeline or run locally before deployment.

### Scan Results & Mitigation
*Before Mitigation:* Base images often have vulnerabilities in installed OS packages.
*After Mitigation:* By updating apt packages during the build (`apt-get update`) and using the latest slim base images, we mitigate most critical OS-level CVEs.

## Secret Management

Zero secrets are committed to the repository.

1. **Local Development:**
   - Secrets are stored in `.env`, which is explicitly added to `.gitignore`.
   - A `.env.example` file is provided with dummy values for reference.

2. **CI/CD Pipeline:**
   - Secrets required for GitHub Actions (e.g., `SERVER_HOST`, `SERVER_USER`, `SERVER_SSH_KEY`, `SLACK_WEBHOOK`, `GITHUB_TOKEN`) are stored in **GitHub Repository Secrets**.
   - These secrets are securely injected into the workflow steps without being exposed in logs.

## Reverse Proxy Security

Caddy is configured as a reverse proxy, providing automatic HTTPS (Let's Encrypt). The `Caddyfile` includes security hardening headers:

```caddyfile
header {
    X-Content-Type-Options nosniff
    X-Frame-Options DENY
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    X-XSS-Protection "1; mode=block"
}
```

## Server Security

The deployment server is hardened using Terraform (`user_data` script):
- **SSH Hardening:** Root login disabled (`PermitRootLogin no`), Password authentication disabled (`PasswordAuthentication no`).
- **Firewall:** UFW is configured to deny incoming traffic by default, only allowing ports `22`, `80`, and `443`.
- **Non-root Deploy User:** A dedicated `deploy` user is used to run Docker commands, preventing the use of root for application management.
- **Unattended Upgrades:** Enabled to automatically install critical security patches on the host OS.
