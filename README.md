## 🔐 Encrypting and Decrypting with SOPS and age

### 1. Encrypting

```bash
sops --age age... -e -i k8s/config/prod/pg-secrets.enc.env
sops --age age... -e -i k8s/config/prod/keycloak-secrets.enc.env
```

### 2. Decrypting

```bash
export SOPS_AGE_KEY=$(<sops/age-keys.txt)
sops -d k8s/config/prod/pg-secrets.enc.env 
sops -d k8s/config/prod/keycloak-secrets.enc.env 
```