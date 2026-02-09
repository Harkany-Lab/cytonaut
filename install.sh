#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  cytonaut bootstrap — installs pixi + all dependencies non-interactively   ║
# ║                                                                            ║
# ║  Usage:                                                                    ║
# ║    Linux / macOS:  bash install.sh                                         ║
# ║    Windows (Git Bash / WSL):  bash install.sh                              ║
# ║    Windows (PowerShell):                                                   ║
# ║      iwr -useb https://pixi.sh/install/install.ps1 | iex                  ║
# ║      pixi install                                                          ║
# ║      pixi run setup-environment                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Colors for pretty output ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ── Step 0: Detect OS ───────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Linux*)   PLATFORM="linux"  ;;
  Darwin*)  PLATFORM="macos"  ;;
  MINGW*|MSYS*|CYGWIN*)  PLATFORM="windows-bash" ;;
  *)        fail "Unsupported OS: $OS. On Windows use PowerShell — see header." ;;
esac
info "Detected platform: $PLATFORM"

# ── Step 1: Install pixi (non-interactive) ──────────────────────────────────
if command -v pixi &>/dev/null; then
  ok "pixi already installed: $(pixi --version)"
else
  info "Installing pixi …"
  curl -fsSL https://pixi.sh/install/install.sh | bash
  # Source the updated PATH so pixi is available in this session
  export PATH="$HOME/.pixi/bin:$PATH"
  if command -v pixi &>/dev/null; then
    ok "pixi installed: $(pixi --version)"
  else
    fail "pixi installation failed. Check https://pixi.sh for manual install."
  fi
fi

# ── Step 2: Navigate to repo root (where pixi.toml lives) ───────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
info "Working directory: $(pwd)"

if [[ ! -f "pixi.toml" ]]; then
  fail "pixi.toml not found in $(pwd). Run this script from the repo root."
fi

# ── Step 3: Install conda-forge dependencies ────────────────────────────────
info "Installing conda-forge/bioconda packages via pixi …"
pixi install
ok "Base environment installed"

# ── Step 4: Run chained setup tasks ─────────────────────────────────────────
# This runs:  configure → bioconductor-install → github-install
info "Configuring BiocManager …"
pixi run configure
ok "BiocManager configured"

info "Installing Bioconductor packages (this may take 5-10 min) …"
pixi run bioconductor-install
ok "Bioconductor packages installed"

info "Installing GitHub packages (dev versions) …"
pixi run github-install
ok "GitHub packages installed"

# ── Step 5: Verify installation ─────────────────────────────────────────────
info "Verifying key packages …"
pixi run -- Rscript -e '
pkgs <- c("Seurat", "tidyverse", "ggplot2", "patchwork", "cowplot",
          "scCustomize", "SingleCellExperiment", "scater", "scran",
          "DESeq2", "gprofiler2", "here", "future")
installed <- sapply(pkgs, requireNamespace, quietly = TRUE)
cat("\n── Package verification ──────────────────────────\n")
for (i in seq_along(pkgs)) {
  status <- if (installed[i]) "\033[32m✓\033[0m" else "\033[31m✗\033[0m"
  cat(sprintf("  %s %s\n", status, pkgs[i]))
}
n_ok <- sum(installed)
cat(sprintf("\n  %d / %d packages verified\n", n_ok, length(pkgs)))
if (n_ok < length(pkgs)) quit(status = 1)
'
ok "All key packages verified"

# ── Step 6: Confirm quarto ──────────────────────────────────────────────────
info "Checking quarto …"
pixi run -- quarto --version
ok "Quarto ready"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  cytonaut environment ready!                                ║${NC}"
echo -e "${GREEN}║                                                             ║${NC}"
echo -e "${GREEN}║  Quick start:                                               ║${NC}"
echo -e "${GREEN}║    pixi run start          # launch radian (R console)      ║${NC}"
echo -e "${GREEN}║    pixi run preview        # live-preview quarto site       ║${NC}"
echo -e "${GREEN}║    pixi run render         # render all notebooks           ║${NC}"
echo -e "${GREEN}║    pixi run rstudio        # launch RStudio                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
