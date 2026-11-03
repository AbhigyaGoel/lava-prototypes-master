# LavaLab Prototypes Master

Central workspace and monorepo containing LavaLab MVP prototypes. Each MVP prototype has its own dedicated directory for rapid development and collaboration.

---

## Directory Structure

```text
lava-prototypes-master/
├── assay/                 # Assay: Hardware verification & agent benchmark suite
├── greenlight/            # Greenlight: Chapter compliance & IRS filing platform
├── unifi/                 # Unifi: Single-use club cards paid from the club's own bank account
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

### 3. `unifi/`
* **Focus**: Single-use virtual cards for student clubs. A treasurer connects the club's bank account and makes a card for one purchase (e.g. $700 for "GBM food"); an officer opens a link to see the card and pays with it. Unifi approves a purchase only if it fits both the card limit and the club's current balance, and never stores card numbers.
* **Stack**: Next.js (App Router), React, TypeScript, Postgres (PGlite locally, Supabase in production), Plaid (bank balance), Lithic (virtual cards and purchase approvals), Vitest.
* **Run it**: `cd unifi && npm install && npm run dev`, then open http://localhost:3000. With no API keys it runs in mock mode, with a fake bank and fake cards, so no accounts are needed. The app is seeded with one club (NSBE at USC) and a $1,240 balance. See [`unifi/README.md`](unifi/README.md) for the demo script, architecture and tests.

---

## Adding a New MVP

When adding a new prototype to this repository:
1. Create a top-level directory for the project: `mkdir my-new-mvp`.
2. Keep dependencies and environment configs self-contained inside the new project directory.
3. Ensure large artifacts, builds, and private credentials (`.env`, `node_modules/`, `build/`, etc.) remain ignored by the root `.gitignore`.
