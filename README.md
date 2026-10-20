# LavaLab Prototypes Master

Central workspace and monorepo containing LavaLab MVP prototypes. Each MVP prototype has its own dedicated directory for rapid development and collaboration.

---

## Directory Structure

```text
lava-prototypes-master/
├── assay/                 # Assay: Hardware verification & agent benchmark suite
├── greenlight/            # Greenlight: Chapter compliance & IRS filing platform
├── assay_runs_archive/    # Historical runs and evaluation benchmark results
└── README.md
```

---

## Projects Overview

### 1. `assay/`
* **Focus**: Automated Verilog/hardware testbench generation, simulation, equivalence checking, and agent grading.
* **Stack**: Python, Icarus Verilog (`iverilog`), cocotb / verification runners.

### 2. `greenlight/`
* **Focus**: Tax-exempt compliance, chapter monitoring, IRS BMF data ingestion, and document extraction.
* **Stack**: Next.js, React, Tailwind CSS, TypeScript, Prisma (Neon Postgres / SQLite).

---

## Adding a New MVP

When adding a new prototype to this repository:
1. Create a top-level directory for the project: `mkdir my-new-mvp`.
2. Keep dependencies and environment configs self-contained inside the new project directory.
3. Ensure large artifacts, builds, and private credentials (`.env`, `node_modules/`, `build/`, etc.) remain ignored by the root `.gitignore`.
