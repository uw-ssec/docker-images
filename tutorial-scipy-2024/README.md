# Tutorial Docker Image

To create the `conda-lock` YAML spec file:

```bash
conda-lock --kind lock --file environment-unpinned.yml
```

To update the `conda-lock` YAML spec file:

```bash
conda-lock -f environment-unpinned.yml --lockfile conda-lock.yml
```

To install the environment:

```bash
conda-lock install -n ssec-scipy2024 conda-lock.yml
```
