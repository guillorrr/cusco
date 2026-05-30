#!/bin/bash
#
# personalize-docs.sh
# Reemplaza el nombre generico del scaffold ("Cusco"/"cusco") por el nombre del
# proyecto del fork en la documentacion (docs/) y, opcionalmente, en el README raiz.
#
# Pensado para correr una sola vez al arrancar un proyecto a partir de Cusco.
# Lo invoca clean-scaffolding.sh, pero tambien se puede correr a mano:
#
#   PROJECT_NAME="MiApp" PROJECT_SLUG="miapp" bash scripts/personalize-docs.sh
#   bash scripts/personalize-docs.sh --dry-run
#   bash scripts/personalize-docs.sh --include-readme
#
# Variables de entorno / defaults:
#   PROJECT_NAME   Nombre propio (default: PROJECT_SLUG capitalizado)
#   PROJECT_SLUG   Slug en minusculas (default: derivado de package.json / git / carpeta)
#

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"

DRY_RUN=false
INCLUDE_README=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run) DRY_RUN=true; shift ;;
        --include-readme) INCLUDE_README=true; shift ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^#//'; exit 0 ;;
        *) echo -e "${RED}Opcion desconocida: $1${NC}"; exit 1 ;;
    esac
done

#######################################
# Deriva el slug del proyecto si no vino por env
#######################################
derive_slug() {
    # 1) package.json name (si ya no es "cusco")
    local pkg="$PROJECT_ROOT/package.json"
    if [[ -f "$pkg" ]]; then
        local name
        name=$(grep -m1 '"name"' "$pkg" | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
        if [[ -n "$name" && "$name" != "cusco" ]]; then
            echo "$name"; return
        fi
    fi
    # 2) basename del remote origin
    local origin
    if origin=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null); then
        local base="${origin##*/}"; base="${base%.git}"
        if [[ -n "$base" && "$base" != "cusco" ]]; then
            echo "$base"; return
        fi
    fi
    # 3) nombre de la carpeta
    basename "$PROJECT_ROOT"
}

# Resolver slug y name
PROJECT_SLUG="${PROJECT_SLUG:-$(derive_slug)}"
# Capitaliza la primera letra para el nombre propio por default
default_name="$(tr '[:lower:]' '[:upper:]' <<< "${PROJECT_SLUG:0:1}")${PROJECT_SLUG:1}"
PROJECT_NAME="${PROJECT_NAME:-$default_name}"

echo ""
echo -e "${BOLD}${CYAN}Personalizacion de documentacion${NC}"
echo -e "  Cusco  -> ${GREEN}${PROJECT_NAME}${NC}"
echo -e "  cusco  -> ${GREEN}${PROJECT_SLUG}${NC}"
[[ "$DRY_RUN" == "true" ]] && echo -e "  ${YELLOW}(dry-run: no se escriben cambios)${NC}"
echo ""

if [[ "$PROJECT_NAME" == "Cusco" && "$PROJECT_SLUG" == "cusco" ]]; then
    echo -e "${YELLOW}El nombre sigue siendo 'Cusco'. Nada que personalizar.${NC}"
    echo -e "${DIM}Pasa PROJECT_NAME / PROJECT_SLUG para cambiarlo.${NC}"
    exit 0
fi

if [[ ! -d "$DOCS_DIR" ]]; then
    echo -e "${RED}No existe la carpeta docs/. Nada que hacer.${NC}"
    exit 0
fi

# Lista de archivos a tocar
mapfile -t TARGETS < <(find "$DOCS_DIR" -name "*.md" -type f | sort)
if [[ "$INCLUDE_README" == "true" && -f "$PROJECT_ROOT/README.md" ]]; then
    TARGETS+=("$PROJECT_ROOT/README.md")
fi

changed=0
for file in "${TARGETS[@]}"; do
    # Cuenta ocurrencias case-sensitive de las dos formas
    local_count=$(grep -cE "Cusco|cusco" "$file" 2>/dev/null || true)
    [[ "${local_count:-0}" -eq 0 ]] && continue

    rel="${file#$PROJECT_ROOT/}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[dry-run]${NC} $rel (${local_count} ocurrencias)"
    else
        # "Cusco" -> nombre propio ; "cusco" -> slug. No toca "CUSCO" (mayusculas, vars de entorno).
        sed -i \
            -e "s/Cusco/${PROJECT_NAME}/g" \
            -e "s/cusco/${PROJECT_SLUG}/g" \
            "$file"
        echo -e "  ${GREEN}+${NC} $rel"
    fi
    changed=$((changed + 1))
done

echo ""
if [[ "$changed" -eq 0 ]]; then
    echo -e "${GREEN}No habia nada para reemplazar (ya estaba personalizado).${NC}"
else
    echo -e "${GREEN}Listo: ${changed} archivo(s) ${DRY_RUN:+(simulado)}.${NC}"
fi
