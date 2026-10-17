#!/usr/bin/env bash
# GEORGE: sincroniza o fork com o rustdesk/rustdesk upstream.
# Uso: scripts/sync-upstream.sh [ref]   (padrão: upstream/master)
# Fluxo: fetch upstream → cria branch sync/upstream-<data> a partir da branch atual →
# merge → regenera workflow/ícones → lista conflitos. Conflitos conhecidos: GEORGE-UPSTREAM.md
set -euo pipefail
REF="${1:-upstream/master}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/rustdesk/rustdesk.git
git fetch upstream --tags
BR="sync/upstream-$(date +%Y%m%d)"
git switch -c "$BR"
if ! git merge --no-edit "$REF"; then
  echo
  echo "== Conflitos (resolva mantendo as marcas // GEORGE: — ver GEORGE-UPSTREAM.md) =="
  git diff --name-only --diff-filter=U
  exit 1
fi
git submodule update --init --recursive
python3 scripts/george-gen-workflow.py
echo "Regenere os ícones se o upstream mudou assets: scripts/george-gen-icons.sh <brand-dir>"
echo "OK: branch $BR pronta. Rode o CI (george-ci.yml) e abra PR para master."
