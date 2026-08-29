# DevOps Infrastructure as Code & Spring Boot CI/CD with Kubernetes

An end-to-end DevOps platform for building, packaging, storing, and deploying a Spring Boot application to Kubernetes with separated Dev and Test environments.

## 1. Project Goal

The project automates the delivery path from source code to a Kubernetes workload while keeping infrastructure and configuration reproducible and version controlled.

The platform is split into two virtual machines:

| Node | Responsibilities |
|---|---|
| VM1 – Control Node | GitLab CE, Docker Compose, Terraform, Ansible |
| VM2 – Kubernetes Node | Minikube, Docker, GitLab Runner, kubectl, Helm |

The Kubernetes cluster is divided into three namespaces:

- `build` – Nexus Repository and artifact/image services
- `dev` – MySQL and Spring Boot application for development
- `test` – MySQL and Spring Boot application for testing

## 2. GitLab Project Layout

The work is split across **two GitLab projects**, on purpose:

| Project | Branches | Contains |
|---|---|---|
| `org/infra` | `build`, `dev`, `test` | Terraform + Ansible for the platform: Nexus (build), MySQL via Helm (dev/test) |
| `org/toystore` | `dev`, `test` | The Spring Boot application: Dockerfile, Helm chart, and its own `.gitlab-ci.yml` per environment |

Each branch in each project is self-contained — its own Terraform state (`TF_STATE_NAME`), its own Ansible role, and (for `toystore`) its own full CI/CD pipeline. This keeps `build`/`dev`/`test` fully isolated from each other while reusing the same automation pattern.

<img width="1920" height="1200" alt="image" src="https://github.com/user-attachments/assets/c123be50-3cd4-4fcf-b0f6-56ca042fe4ff" />

![Toystore project — repository layout](images/toystore-repo-layout.png)

## 3. Architecture

```text
                         ┌──────────────────────────────┐
                         │ VM1 – Control Node            │
                         │                              │
                         │ GitLab CE                    │
                         │ Docker Compose               │
                         │ Terraform                    │
                         │ Ansible                      │
                         └──────────────┬───────────────┘
                                        │
                              configuration / delivery
                                        │
                         ┌──────────────▼───────────────┐
                         │ VM2 – Kubernetes Node         │
                         │                              │
                         │ Minikube + Docker             │
                         │ GitLab Runner                │
                         │ kubectl + Helm               │
                         │                              │
                         │ ┌──────── build ───────────┐ │
                         │ │ Nexus Repository         │ │
                         │ │ Docker / Maven artifacts │ │
                         │ └──────────────────────────┘ │
                         │                              │
                         │ ┌──────── dev ─────────────┐ │
                         │ │ MySQL + Spring Boot     │ │
                         │ │ ConfigMap + Secrets     │ │
                         │ └──────────────────────────┘ │
                         │                              │
                         │ ┌──────── test ────────────┐ │
                         │ │ MySQL + Spring Boot     │ │
                         │ │ ConfigMap + Secrets     │ │
                         │ └──────────────────────────┘ │
                         └──────────────────────────────┘
```

## 4. Technology Stack

### Infrastructure as Code
- Terraform – infrastructure/resource provisioning
- Ansible – host/platform configuration

### Source / CI/CD
- GitLab CE
- GitLab Runner (Shell executor)
- GitLab CI/CD
- Git

### Containers / Kubernetes
- Docker
- Kubernetes
- Minikube
- kubectl
- Helm

### Artifact / Data / Application
- Nexus Repository
- Maven
- MySQL 8.4
- Spring Boot (Java 8, OpenJDK)

## 5. Kubernetes Namespace Design

### `build`
Contains Nexus Repository. Nexus is used as the central artifact hub for Docker images and Maven artifacts.

### `dev`
Contains the development database (MySQL, via Helm) and the Spring Boot deployment (via Helm).

### `test`
Contains the test database (MySQL, via Helm) and the Spring Boot deployment (via Helm), independent from `dev`.

This namespace separation keeps the environments isolated while allowing the same Helm deployment pattern to be reused.

## 6. Infrastructure Provisioning

Terraform is responsible for creating/provisioning the Kubernetes namespace and platform resources for each branch (`build`, `dev`, `test`).

Typical lifecycle:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

For CI validation, backend initialization can be disabled when a remote state backend is not required:

```bash
terraform init -backend=false
terraform validate
```

## 7. Configuration Management

Ansible configures the Kubernetes node and platform services after provisioning.

The automation is executed with an explicit Ansible configuration file:

```bash
cd ansible
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook --syntax-check playbooks/site.yml
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook playbooks/site.yml
```

- **build branch**: installs Helm, configures Nexus (Docker realm, anonymous read access, EULA acceptance, `docker-hosted` repository).
- **dev / test branches**: verifies Helm, then runs `helm upgrade --install` for the MySQL chart with the environment's database credentials.

## 8. Nexus Repository

Nexus runs in the `build` namespace and provides:

- Docker hosted registry (`docker-hosted`)
- Maven artifact storage
- Central image/artifact management for CI/CD

Docker registry endpoint used by the environment:

```text
192.168.49.2:31972
```

Nexus UI is exposed through the environment's port-forward configuration (`kubectl -n build port-forward svc/nexus 31971:8081 31972:8082`).

### Registry validation

The GitLab Runner was validated end-to-end against Nexus before relying on it from Kubernetes:

1. Login
2. Pull a base image
3. Tag the image
4. Push the image to Nexus
5. Remove the local tag
6. Pull the image back from Nexus

This proves the Runner-to-Nexus path independently from Kubernetes image pulling.

## 9. MySQL (deployed via Helm)

MySQL is deployed separately in `dev` and `test`, **as a Helm release**, not a raw manifest — this is an explicit assignment requirement. Each branch's Ansible role packages a small self-contained chart (`Chart.yaml`, `values.yaml`, `templates/{secret,pvc,deployment,service}.yaml`) and installs it with `helm upgrade --install mysql-dev|mysql-test`.

Environment-specific Kubernetes Secrets provide database credentials:

```text
mysql-dev-secret
mysql-test-secret
```

The application receives non-secret connection information through a ConfigMap and credentials through these Secrets.

## 10. Database Initialization

The seed script `Database/toystore-test.sql` (from the source repository) is imported into the running MySQL pod as part of the `toystore` project's pipeline (`db_import` job, manual):

```bash
kubectl -n <namespace> cp Database/toystore-test.sql <mysql-pod>:/tmp/toystore-test.sql
kubectl -n <namespace> exec deployment/mysql -- sh -c \
  'mysql -uroot -p"$ROOT_PASSWORD" < /tmp/toystore-test.sql'
```

The script is self-contained (`DROP DATABASE IF EXISTS toystore; CREATE DATABASE toystore;`), so re-running it resets the schema and seed data to a known state.

## 11. Spring Boot Application

The application uses environment-driven database configuration — no hardcoded environment-specific values ship in the package:

```properties
spring.datasource.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
server.port=8080
```

## 12. Docker Image

The application is packaged into a lightweight OpenJDK 8 runtime image:

```dockerfile
FROM eclipse-temurin:8-jre-jammy
WORKDIR /app
COPY app.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

The resulting image is tagged with the Git commit SHA and an environment tag (`dev-latest` / `test-latest`), and pushed to Nexus.

## 13. Helm Deployment (Application)

The application is packaged as a Helm chart, per environment, with:

- `Chart.yaml`
- `values.yaml`
- `templates/deployment.yaml`
- `templates/service.yaml`
- `templates/configmap.yaml`

Environment-specific values include: namespace, image repository, image tag, MySQL secret name, MySQL service name, database name, replica count.

Example deployment command:

```bash
helm upgrade --install toystore-dev ./helm \
  --namespace dev \
  --set image.repository=192.168.49.2:31972/toystore \
  --set image.tag=<COMMIT_SHA> \
  --set-string imagePullSecrets[0].name=nexus-registry-secret
```

## 14. CI/CD Pipeline (org/toystore)

Each branch (`dev`, `test`) runs its own complete, four-stage pipeline:

```text
checkout_and_build (auto)
  ↓
dockerize_and_push (auto)
  ↓
db_import (manual)
  ↓
deploy (manual)
```

### `checkout_and_build`
- Clones the application source from the upstream GitHub repository
- Injects the environment-specific `application.properties`
- Runs `mvn clean package`
- Publishes the JAR and the database script as artifacts

### `dockerize_and_push`
- Authenticates to Nexus (credential from a masked CI/CD variable)
- Builds the application image
- Tags it with the commit SHA and an environment tag
- Pushes both tags to Nexus

### `db_import` (manual)
- Copies `toystore-test.sql` into the running MySQL pod
- Reads the MySQL root password from the environment's Kubernetes Secret
- Executes the script inside the pod

Kept manual and independent from `deploy` so the operator decides when to (re)seed data.

### `deploy` (manual)
- Ensures a `nexus-registry-secret` exists for the namespace
- Loads the built image directly into the Minikube node (`minikube image load`) — a deliberate choice for this nested-Minikube lab environment, described in the troubleshooting notes below
- Runs `helm upgrade --install`
- Waits for the rollout to complete

## 15. Application Deployment Model

```text
                 Nexus
                   │
             Docker image
                   │
                   ▼
       minikube image load (loaded directly
       into the node for this environment)
                   │
                   ▼
            Spring Boot Pod
               │       │
               │       └── Kubernetes Secret → DB credentials
               │
               └────────── ConfigMap → DB host/port/name
                               │
                               ▼
                            MySQL (Helm release)
```

External access for verification is provided through a `kubectl port-forward` on the application's Service NodePort, exposed on the Kubernetes VM's IP.

## 16. Installation / Delivery Order

1. Prepare VM1 and VM2.
2. Install Docker / GitLab CE (via `docker-compose.yml`) / Terraform / Ansible on VM1.
3. Install Minikube / Docker / kubectl / Helm / OpenJDK 8 / Maven / GitLab Runner on VM2.
4. Create `build`, `dev`, and `test` namespaces (Terraform, per branch in `org/infra`).
5. Configure platform services with Ansible (per branch in `org/infra`).
6. Deploy/verify Nexus in `build`.
7. Deploy MySQL to `dev` and `test` via Helm.
8. Push the `org/toystore` project (branches `dev`, `test`).
9. Run each branch's pipeline: build → push image → (manual) import DB → (manual) deploy.
10. Verify the Kubernetes Deployment, Pod, Service, and the application's REST endpoints.

## 17. Operational Validation Commands

### Kubernetes

```bash
kubectl get nodes
kubectl get pods -A
kubectl -n dev get all
kubectl -n test get all
```

### Helm

```bash
helm version
helm list -A
```

### Nexus / Docker registry

```bash
docker login 192.168.49.2:31972
```

### Application rollout and verification

```bash
kubectl -n dev rollout status deployment/toystore --timeout=300s
kubectl -n dev get pods -o wide
curl http://<node-ip>:<nodeport>/categories
curl http://<node-ip>:<nodeport>/products
```

## 18. Troubleshooting Notes

### Helm command not found
The GitLab Runner used an explicit Helm path/PATH export in every job:
```bash
export PATH="/home/gitlab-runner/.local/bin:/usr/local/bin:$PATH"
```

### MySQL `using password: NO`
The original CI implementation depended on an empty/missing CI variable. The final pattern reads the root password from the Kubernetes Secret instead.

### Nexus EULA gate on the Docker API
Nexus returned 403 on `/v2/` for every configuration attempt (realms, anonymous access, custom roles) until the EULA was explicitly accepted via the REST API — Nexus was blocking all API/registry traffic pending onboarding. Fix: `GET` the current disclaimer text and `POST` it back verbatim with `accepted: true`.

### `ImagePullBackOff` / `http: server gave HTTP response to HTTPS client`
The Minikube node's own Docker daemon (separate from the host VM's daemon) didn't trust the insecure Nexus registry, and reconfiguring it repeatedly caused Minikube instability on this nested VM setup. Final approach: build and push the image to Nexus as required by the assignment, but **load the image directly into the Minikube node** (`minikube image load`) for the actual deployment, with `imagePullPolicy: Never` on the Deployment. A scoped, passwordless `sudo` rule lets the `gitlab-runner` user run `minikube image load` as the user who owns the real Minikube profile.

### GitLab Runner shell environment quirks
Multi-line pipeline edits made through terminal `sed`/heredocs occasionally merged two script lines into one (a step silently became an argument to `echo` instead of running). Fixed by rewriting affected jobs with a small Python script that replaces the whole job block atomically, rather than patching line-by-line.

## 19. Security Notes

- Keep Nexus credentials in GitLab protected/masked CI/CD variables.
- Do not commit plaintext passwords into Git.
- Keep Kubernetes database credentials in Secrets.
- Keep non-sensitive DB connection settings in ConfigMaps.
- Limit service accounts and privileges to the required namespace/resources.

## 20. Repository Structure

```text
.
├── README.md
├── docker-compose.yml
├── infra/
│   ├── build-branch/
│   │   ├── terraform/
│   │   ├── ansible/
│   │   └── pipelines/
│   ├── dev-branch/
│   │   ├── terraform/
│   │   ├── ansible/
│   │   └── pipelines/
│   └── test-branch/
│       ├── terraform/
│       ├── ansible/
│       └── pipelines/
├── toystore-project/
│   ├── dev/
│   │   ├── .gitlab-ci.yml
│   │   ├── Dockerfile
│   │   ├── application.properties
│   │   └── helm/
│   └── test/
│       ├── .gitlab-ci.yml
│       ├── Dockerfile
│       ├── application.properties
│       └── helm/
├── database/
│   └── toystore-test.sql
└── images/
    ├── infra-repo-layout.png
    └── toystore-repo-layout.png
```

## 21. Assignment Deliverables Checklist

- [x] Private GitHub repository
- [x] `README.md`
- [x] Terraform scripts (build/dev/test)
- [x] Ansible playbooks (build/dev/test)
- [ ] `docker-compose.yml` — attach the file used to bring up GitLab CE on VM1
- [x] GitLab CI files (`toystore-project/dev/.gitlab-ci.yml`, `.../test/.gitlab-ci.yml`)
- [x] Helm charts (MySQL and Spring Boot application, both environments)
- [x] Database initialization/import script (`toystore-test.sql`)
- [x] Final presentation

## 22. Final Review Before Submission

Before handing over the repository, verify:

```bash
git status
git branch -vv
git log --oneline -5
```

Confirm that no secrets/passwords have been committed:

```bash
git grep -nEi 'password|passwd|token|secret' -- ':!README.md'
```

Then verify the target repository contains all required assignment deliverables listed in Section 21.
