# Create the three branches

Start from an empty or clean clone of `org/infra`.

```bash
git clone https://gitlab.local/org/infra.git
cd infra
```

Copy the contents of each branch package onto the corresponding branch.

## Build branch

```bash
git checkout -b build
tar... # copy the files from build-branch into the repository root
git add .
git commit -m "Add build environment infrastructure"
git push -u origin build
```

## Dev branch

```bash
git checkout main
git checkout -b dev
# copy the files from dev-branch into the repository root
git add .
git commit -m "Add dev environment infrastructure"
git push -u origin dev
```

## Test branch

```bash
git checkout main
git checkout -b test
# copy the files from test-branch into the repository root
git add .
git commit -m "Add test environment infrastructure"
git push -u origin test
```

The repository can use a protected `main` branch for documentation only. Environment changes happen through `build`, `dev`, and `test`.
