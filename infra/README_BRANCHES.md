# Branch contents

## build
Terraform: build namespace, Nexus PVC, Deployment, NodePort Service.
Ansible: install Helm and configure Nexus Docker hosted repository.

## dev
Terraform: dev namespace.
Ansible: MySQL Dev using `mysql-dev.yml.j2`.

## test
Terraform: test namespace.
Ansible: MySQL Test using `mysql-test.yml.j2`.

## Runtime variables for Dev/Test
Set these GitLab CI/CD variables (masked/protected as appropriate):

`MYSQL_ROOT_PASSWORD`
`MYSQL_PASSWORD`

The pipeline should pass them to Ansible at runtime. Do not commit real passwords.
