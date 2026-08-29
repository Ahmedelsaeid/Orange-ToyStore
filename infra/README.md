# INFRA Branch-Based Lab

## Architecture

WORK LAPTOP
- GitLab VM: `192.168.1.10`
- GitLab CE over HTTPS: `https://gitlab.local`
- Terraform installed
- Ansible installed

LOCAL LAB LAPTOP
- Minikube VM: `192.168.184.128`
- Kubernetes 1.35.1
- GitLab Runner 19.3.1
- Shell executor
- Docker, kubectl available
- Runner kubeconfig: `/home/gitlab-runner/.kube/config`
- GitLab CA trusted

## Branches

We use **three branches** because the requirement is one branch per environment/task:

- `build` -> build namespace + Nexus + Helm
- `dev` -> dev namespace + MySQL Dev
- `test` -> test namespace + MySQL Test

Each branch has its own Terraform HTTP state name so states do not collide:

- `build`
- `dev`
- `test`

## Pipeline order

Every branch is manual and runs:

Validate -> Plan -> Apply -> Configure

Do not run `apply` before `plan` succeeds.

## Network notes

The GitLab VM is bridged and currently uses `192.168.1.10`.
The Minikube VM remains on VMware NAT and currently uses `192.168.184.128`.
The Minikube VM can reach `https://gitlab.local` using the trusted internal CA.

## Nexus design

Nexus 3.95.1 in namespace `build`:

- Web service: `31971 -> 8081`
- Docker registry: `31972 -> 8082`
- PVC: `10Gi`
- Replica: `1`
- CPU request/limit: `500m/2`
- Memory request/limit: `1.5Gi/2.5Gi`

Nexus intentionally uses a startup probe because first startup can take several minutes on a small lab VM.

## MySQL design

The `dev` and `test` branches each create:

- PVC: `2Gi`
- Secret
- MySQL 8.4 Deployment
- ClusterIP Service on 3306

The Kubernetes manifests are separate Jinja2 files, not large inline `shell` heredocs.

## Security note

Do not commit real passwords. Put these values in GitLab CI/CD variables or Ansible Vault:

- `MYSQL_ROOT_PASSWORD`
- `MYSQL_PASSWORD`
- `NEXUS_ADMIN_PASSWORD` (only needed after Nexus initial password is no longer available)

For the lab, non-secret defaults are kept in variables files; secret values should be supplied at runtime.
