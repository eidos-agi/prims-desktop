# prim.product — Prims Desktop

This directory is the product pack for **Prims Desktop**.

Canonical graph: [`product.json`](product.json).

It is an OPF v1 packet (`format: opf`). Markdown here is a projection of the product graph; product decisions belong in `product.json`.

## Stamped decision — profiles and storage

Prims Desktop is installed once on the Mac, but a person can have multiple **Prims profiles**.

A small setup file under `~/prims` points Prims Desktop to the default Prims folder for the selected profile. Each profile has its own folder on a drive, and that folder contains that profile's settings and Prims.

Conceptually:

```text
Prims Desktop.app
        │
        ▼
~/prims/<setup>          machine-local profile pointer / registry
        │
        ├── Work      → /path/to/work-prims/
        ├── Personal  → /path/to/personal-prims/
        └── Lab       → /Volumes/Lab/Prims/
```

Each profile root is its own Prims world:

```text
<profile-root>/
  settings / configuration
  prims
  profile-specific state
```

The exact bootstrap filename and serialized schema under `~/prims` are not locked by this decision.
