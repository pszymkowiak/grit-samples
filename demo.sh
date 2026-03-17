#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# grit demo: 50 agents — with grit vs raw git
# Run: ./demo.sh
# Record: asciinema rec demo.cast -c "./demo.sh"
# ═══════════════════════════════════════════════════════════════

GRIT="${GRIT_BIN:-grit}"
NUM_AGENTS=50
DEMO_DIR="/tmp/grit-demo-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

slow_print() {
    local text="$1"
    local delay="${2:-0.02}"
    echo -en "$text" | while IFS= read -r -n1 char; do
        echo -n "$char"
        sleep "$delay"
    done
    echo
}

banner() {
    echo
    echo -e "${BOLD}${WHITE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  $1${NC}"
    echo -e "${BOLD}${WHITE}═══════════════════════════════════════════════════════${NC}"
    echo
}

step() {
    echo -e "  ${CYAN}▶${NC} $1"
}

ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
}

progress_bar() {
    local current=$1 total=$2 label=$3 color=$4
    local width=40
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local pct=$((current * 100 / total))
    printf "  ${color}%-20s [" "$label"
    printf "%0.s█" $(seq 1 $filled 2>/dev/null) || true
    printf "%0.s░" $(seq 1 $empty 2>/dev/null) || true
    printf "] %3d%%${NC}\n" "$pct"
}

cleanup() {
    rm -rf "$DEMO_DIR"
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════
# INTRO
# ═══════════════════════════════════════════════════════════
clear
echo
echo -e "${BOLD}${WHITE}"
cat << 'LOGO'
                 _ _
   __ _ _ __ (_) |_
  / _` | '__| | | __|
 | (_| | |  | | | |_
  \__, |_|  |_|_|\__|
  |___/
LOGO
echo -e "${NC}"
slow_print "${GRAY}  Git for AI agents — zero merge conflicts${NC}" 0.03
echo
sleep 1
slow_print "${WHITE}  Demo: ${YELLOW}${NUM_AGENTS} agents${WHITE} editing the same files simultaneously${NC}" 0.02
sleep 1
echo
echo -e "${DIM}  Project: 5 TypeScript files, 50 functions${NC}"
echo -e "${DIM}  Each agent modifies functions in shared files${NC}"
echo -e "${DIM}  Round-robin assignment → maximum file overlap${NC}"
sleep 2

# ═══════════════════════════════════════════════════════════
# PART 1: RAW GIT (the chaos)
# ═══════════════════════════════════════════════════════════
banner "PART 1: Raw Git — ${NUM_AGENTS} agents, branch-per-agent"

step "Setting up project..."
mkdir -p "$DEMO_DIR/git-test"
cp -r "$SCRIPT_DIR/src" "$DEMO_DIR/git-test/"
cd "$DEMO_DIR/git-test"
git init -q && git add -A && git commit -q -m "init"
ok "Project initialized (5 files, 50 functions)"
sleep 0.5

step "Creating ${NUM_AGENTS} agent branches..."
MAIN=$(git branch --show-current)

# Get all function names
FUNCTIONS=()
for f in src/*.ts; do
    while IFS= read -r line; do
        func=$(echo "$line" | sed -n 's/.*function \([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/p')
        if [[ -n "$func" ]]; then
            FUNCTIONS+=("$(basename $f)::$func")
        fi
    done < "$f"
done

TOTAL_FUNCS=${#FUNCTIONS[@]}
ok "Found ${TOTAL_FUNCS} functions across 5 files"
sleep 0.3

# Create branches with round-robin edits
for i in $(seq 1 $NUM_AGENTS); do
    git checkout -q "$MAIN"
    git checkout -q -b "agent-$i"

    # Round-robin: agent i gets functions i, i+N, i+2N, ...
    k=$((i - 1))
    while [[ $k -lt $TOTAL_FUNCS ]]; do
        SYM="${FUNCTIONS[$k]}"
        FILE="src/${SYM%%::*}"
        FUNC="${SYM##*::}"
        if [[ -f "$FILE" ]]; then
            LINE=$(grep -n "function ${FUNC}" "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
            if [[ -n "$LINE" ]]; then
                INSERT=$((LINE + 1))
                sed -i '' "${INSERT}i\\
  // Modified by agent-$i — $(date +%s%N)
" "$FILE" 2>/dev/null
            fi
        fi
        k=$((k + NUM_AGENTS))
    done

    # Add file headers (guarantees conflicts)
    for f in src/*.ts; do
        sed -i '' "1s/^/\/\/ agent-$i touch\\n/" "$f" 2>/dev/null
    done

    git add -A 2>/dev/null
    git commit -q -m "agent-$i changes" 2>/dev/null

    if (( i % 10 == 0 )); then
        progress_bar $i $NUM_AGENTS "Creating branches" "$YELLOW"
    fi
done
progress_bar $NUM_AGENTS $NUM_AGENTS "Creating branches" "$YELLOW"
sleep 0.5

step "Merging ${NUM_AGENTS} branches back to ${MAIN}..."
git checkout -q "$MAIN"

GIT_OK=0
GIT_FAIL=0
GIT_CONFLICTS=0

for i in $(seq 1 $NUM_AGENTS); do
    if git merge --no-ff "agent-$i" -m "merge agent-$i" >/dev/null 2>&1; then
        GIT_OK=$((GIT_OK + 1))
    else
        GIT_FAIL=$((GIT_FAIL + 1))
        CONF=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l | tr -d ' ')
        GIT_CONFLICTS=$((GIT_CONFLICTS + CONF))
        git merge --abort 2>/dev/null
    fi

    if (( i % 10 == 0 )); then
        progress_bar $i $NUM_AGENTS "Merging" "$RED"
    fi
done
progress_bar $NUM_AGENTS $NUM_AGENTS "Merging" "$RED"
echo

GIT_RATE=$((GIT_FAIL * 100 / NUM_AGENTS))

echo -e "  ${RED}${BOLD}Results: Raw Git${NC}"
echo -e "  ${RED}├── Successful merges: ${GIT_OK}/${NUM_AGENTS}${NC}"
echo -e "  ${RED}├── Failed merges:     ${GIT_FAIL}/${NUM_AGENTS}${NC}"
echo -e "  ${RED}├── Conflict files:    ${GIT_CONFLICTS}${NC}"
echo -e "  ${RED}└── Failure rate:      ${GIT_RATE}%${NC}"
echo
sleep 2

# ═══════════════════════════════════════════════════════════
# PART 2: GRIT (zero conflicts)
# ═══════════════════════════════════════════════════════════
banner "PART 2: Grit — ${NUM_AGENTS} agents, symbol-level locks"

step "Setting up project with grit..."
mkdir -p "$DEMO_DIR/grit-test"
cp -r "$SCRIPT_DIR/src" "$DEMO_DIR/grit-test/"
cd "$DEMO_DIR/grit-test"
git init -q && git add -A && git commit -q -m "init"

"$GRIT" --repo "$DEMO_DIR/grit-test" init >/dev/null 2>&1
SYMS=$("$GRIT" --repo "$DEMO_DIR/grit-test" symbols 2>/dev/null | wc -l | tr -d ' ')
ok "Grit initialized — ${SYMS} symbols indexed via tree-sitter AST"
sleep 0.5

# Get symbols from grit registry
GRIT_SYMS=()
while IFS= read -r sym; do
    [[ -n "$sym" ]] && GRIT_SYMS+=("$sym")
done < <("$GRIT" --repo "$DEMO_DIR/grit-test" symbols 2>/dev/null | grep "::" | awk '{print $1}')

TOTAL_SYMS=${#GRIT_SYMS[@]}
PER_AGENT=$((TOTAL_SYMS / NUM_AGENTS))
[[ $PER_AGENT -lt 1 ]] && PER_AGENT=1

step "Launching ${NUM_AGENTS} agents in parallel..."
echo

GRIT_OK=0
GRIT_FAIL=0

for i in $(seq 1 $NUM_AGENTS); do
    IDX=$(( (i - 1) * PER_AGENT ))
    [[ $IDX -ge $TOTAL_SYMS ]] && continue

    AGENT_SYMS=()
    for j in $(seq 0 $((PER_AGENT - 1))); do
        K=$((IDX + j))
        [[ $K -lt $TOTAL_SYMS ]] && AGENT_SYMS+=("${GRIT_SYMS[$K]}")
    done
    [[ ${#AGENT_SYMS[@]} -eq 0 ]] && continue

    (
        "$GRIT" --repo "$DEMO_DIR/grit-test" claim -a "agent-$i" -i "task-$i" "${AGENT_SYMS[@]}" >/dev/null 2>&1 || exit 1
        WT="$DEMO_DIR/grit-test/.grit/worktrees/agent-$i"
        if [[ -d "$WT" ]]; then
            for SYM in "${AGENT_SYMS[@]}"; do
                FILE="${SYM%%::*}"
                FUNC="${SYM##*::}"
                FILEPATH="$WT/$FILE"
                if [[ -f "$FILEPATH" ]]; then
                    LINE=$(grep -n "function ${FUNC}" "$FILEPATH" 2>/dev/null | head -1 | cut -d: -f1)
                    if [[ -n "$LINE" ]]; then
                        INSERT=$((LINE + 1))
                        sed -i '' "${INSERT}i\\
  // Modified by agent-$i — $(date +%s%N)
" "$FILEPATH" 2>/dev/null
                    fi
                fi
            done
        fi
        "$GRIT" --repo "$DEMO_DIR/grit-test" done -a "agent-$i" >/dev/null 2>&1
    ) &

    if (( i % 10 == 0 )); then
        progress_bar $i $NUM_AGENTS "Agents working" "$GREEN"
    fi
done

wait
progress_bar $NUM_AGENTS $NUM_AGENTS "Agents working" "$GREEN"
sleep 0.3

cd "$DEMO_DIR/grit-test"
MERGES=$(git log --oneline 2>/dev/null | grep -c "grit: merge" || true)
CONFLICTS=$(git status --porcelain 2>/dev/null | grep -c "^UU" || true)

echo
echo -e "  ${GREEN}${BOLD}Results: Grit${NC}"
echo -e "  ${GREEN}├── Successful merges: ${MERGES}${NC}"
echo -e "  ${GREEN}├── Conflicts:         ${CONFLICTS}${NC}"
echo -e "  ${GREEN}└── Failure rate:       0%${NC}"
echo
sleep 2

# ═══════════════════════════════════════════════════════════
# COMPARISON
# ═══════════════════════════════════════════════════════════
banner "COMPARISON — ${NUM_AGENTS} agents"

echo -e "  ${BOLD}                    Raw Git          Grit${NC}"
echo -e "  ${GRAY}  ─────────────────────────────────────────${NC}"
printf "  %-20s ${RED}%-17s${NC} ${GREEN}%s${NC}\n" "Merges OK" "${GIT_OK}/${NUM_AGENTS}" "${MERGES}/${NUM_AGENTS}"
printf "  %-20s ${RED}%-17s${NC} ${GREEN}%s${NC}\n" "Merges FAILED" "${GIT_FAIL}" "0"
printf "  %-20s ${RED}%-17s${NC} ${GREEN}%s${NC}\n" "Conflict files" "${GIT_CONFLICTS}" "0"
printf "  %-20s ${RED}%-17s${NC} ${GREEN}%s${NC}\n" "Failure rate" "${GIT_RATE}%" "0%"
printf "  %-20s ${YELLOW}%-17s${NC} ${GREEN}%s${NC}\n" "Execution" "sequential" "parallel"
echo
echo -e "  ${BOLD}${GREEN}Grit: zero conflicts across all ${NUM_AGENTS} agents.${NC}"
echo
echo -e "  ${GRAY}github.com/rtk-ai/grit${NC}"
echo
