# grit-samples

Demo project for [grit](https://github.com/rtk-ai/grit) — **Git for AI agents**.

This repo contains a sample TypeScript project (5 files, 50 functions) and a demo script that runs **50 agents simultaneously** — first with raw git (chaos), then with grit (zero conflicts).

![grit demo — 50 agents](demo.gif)

## Run the demo

```bash
# Prerequisites: grit installed (cargo install --git https://github.com/rtk-ai/grit)

git clone https://github.com/pszymkowiak/grit-samples.git
cd grit-samples
./demo.sh
```

## Record as GIF

```bash
# Install asciinema + agg
brew install asciinema
cargo install --git https://github.com/asciinema/agg

# Record
asciinema rec demo.cast -c "./demo.sh"

# Convert to GIF
agg demo.cast demo.gif --cols 100 --rows 35 --speed 2
```

## What it shows

### Part 1: Raw Git — 50 agents, branch-per-agent

Each agent creates a branch, edits functions (round-robin across shared files), then merges back. Git detects conflicting hunks because multiple branches touched the same files.

**Result: ~70-85% merge failure rate**

### Part 2: Grit — 50 agents, symbol-level locks

Each agent claims specific functions via `grit claim`, works in an isolated worktree, then `grit done` rebases and merges automatically. Functions are locked at the AST level — different functions in the same file never conflict.

**Result: 0% failure rate, 0 conflicts**

## Project structure

```
src/
├── auth.ts           # 10 functions (user management)
├── api.ts            # 10 functions (product management)
├── orders.ts         # 10 functions (order management)
├── notifications.ts  # 10 functions (notification system)
├── analytics.ts      # 10 functions (analytics & reporting)
└── db.ts             # 5 functions  (database abstraction)
```

## Links

- **grit**: [github.com/rtk-ai/grit](https://github.com/rtk-ai/grit)
- **License**: MIT
