#!/bin/bash
#
# clean-scaffolding.sh
# Limpia el contenido de ejemplo del scaffolding Cusco para preparar el proyecto para forks
#
# Uso: npm run clean:scaffolding
#      o directamente: bash scripts/clean-scaffolding.sh
#
# IMPORTANTE: Este script compara contra el repositorio upstream de Cusco
# para determinar que archivos son del scaffolding base. Solo elimina archivos
# que existen en upstream. Archivos nuevos del fork son preservados automaticamente.
#

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Directorio raiz del proyecto (relativo al script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# URL del repositorio upstream de Cusco
# Puedes sobrescribir esta URL con la variable de entorno CUSCO_UPSTREAM_URL
UPSTREAM_URL="${CUSCO_UPSTREAM_URL:-git@github.com:guillorrr/cusco.git}"
UPSTREAM_BRANCH="${CUSCO_UPSTREAM_BRANCH:-main}"

# Patrones de archivos/directorios del scaffolding base a limpiar
# Estos patrones se usan para filtrar que archivos de upstream son scaffolding
SCAFFOLDING_PATTERNS=(
    # =========================================================================
    # Backend - NestJS modules de ejemplo
    # =========================================================================
    "src/api/src/modules/users/"
    "src/api/src/modules/auth/"
    "src/api/prisma/seed.ts"

    # =========================================================================
    # Frontend - Componentes de ejemplo (Atomic Design)
    # =========================================================================
    # Atoms
    "src/frontend/src/app/atoms/button/"
    "src/frontend/src/app/atoms/input/"
    # Molecules
    "src/frontend/src/app/molecules/card/"
    "src/frontend/src/app/molecules/form-field/"
    # Pages
    "src/frontend/src/app/pages/home/"
    "src/frontend/src/app/pages/login/"
    # Core services de ejemplo
    "src/frontend/src/app/core/services/auth.service.ts"
    "src/frontend/src/app/core/guards/auth.guard.ts"
    "src/frontend/src/app/core/interceptors/auth.interceptor.ts"
    "src/frontend/src/app/core/models/user.model.ts"
)

# Contadores globales
DELETED_COUNT=0
SKIPPED_COUNT=0
MODIFIED_COUNT=0

# Arrays para tracking
declare -a UPSTREAM_FILES=()
declare -a BASE_FILES=()
declare -a FORK_FILES=()
declare -a MODIFIED_FILES=()
declare -a UNMODIFIED_FILES=()

# Flags
AUTO_YES=false
DRY_RUN=false
VERBOSE=false

# Resultado de la accion principal
MAIN_ACTION=""

#######################################
# Muestra el banner inicial
#######################################
show_banner() {
    echo ""
    echo -e "${CYAN}+==============================================================+${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}Cusco - Clean Scaffolding${NC}                                   ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  Compara con upstream, preserva archivos del fork           ${CYAN}|${NC}"
    echo -e "${CYAN}+==============================================================+${NC}"
    echo ""
}

#######################################
# Muestra ayuda
#######################################
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help      Muestra esta ayuda"
    echo "  -y, --yes       Modo no interactivo (elimina todo el scaffolding base sin preguntar)"
    echo "  -d, --dry-run   Muestra que se eliminaria sin hacer cambios"
    echo "  -v, --verbose   Muestra mas detalles (lista archivos del fork preservados)"
    echo ""
    echo "FUNCIONAMIENTO:"
    echo "  Este script compara tu proyecto con el repositorio upstream de Cusco"
    echo "  para determinar que archivos son del scaffolding base original."
    echo ""
    echo "  - Archivos que EXISTEN en upstream: Son del scaffolding base (candidatos a eliminar)"
    echo "  - Archivos que NO EXISTEN en upstream: Son del fork (preservados automaticamente)"
    echo "  - Archivos base MODIFICADOS localmente: Se pregunta antes de eliminar"
    echo ""
    echo "VARIABLES DE ENTORNO:"
    echo "  CUSCO_UPSTREAM_URL      URL del repositorio upstream (default: git@github.com:guillorrr/cusco.git)"
    echo "  CUSCO_UPSTREAM_BRANCH   Branch de upstream (default: main)"
    echo ""
}

#######################################
# Verifica y configura el remote upstream
#######################################
setup_upstream() {
    echo -e "${BOLD}Verificando configuracion de upstream...${NC}"

    # Verificar si el remote upstream existe
    if ! git -C "$PROJECT_ROOT" remote get-url upstream &>/dev/null; then
        echo -e "${YELLOW}Remote 'upstream' no configurado.${NC}"
        echo -e "Configurando upstream: ${CYAN}$UPSTREAM_URL${NC}"

        if ! git -C "$PROJECT_ROOT" remote add upstream "$UPSTREAM_URL" 2>/dev/null; then
            echo -e "${RED}Error: No se pudo agregar el remote upstream${NC}"
            return 1
        fi
        echo -e "${GREEN}+${NC} Remote upstream agregado"
    else
        local current_url
        current_url=$(git -C "$PROJECT_ROOT" remote get-url upstream)
        echo -e "${GREEN}+${NC} Remote upstream configurado: ${DIM}$current_url${NC}"
    fi

    # Fetch del upstream
    echo -e "${BOLD}Obteniendo informacion de upstream...${NC}"
    if ! git -C "$PROJECT_ROOT" fetch upstream "$UPSTREAM_BRANCH" --quiet 2>/dev/null; then
        echo -e "${RED}Error: No se pudo hacer fetch de upstream${NC}"
        echo -e "${DIM}Verifica tu conexion a internet y que el repositorio exista${NC}"
        return 1
    fi
    echo -e "${GREEN}+${NC} Informacion de upstream actualizada"

    return 0
}

#######################################
# Obtiene la lista de archivos del scaffolding desde upstream
#######################################
get_upstream_scaffolding_files() {
    echo -e "${BOLD}Obteniendo lista de archivos de scaffolding desde upstream...${NC}"

    local all_upstream_files
    all_upstream_files=$(git -C "$PROJECT_ROOT" ls-tree -r --name-only "upstream/$UPSTREAM_BRANCH" 2>/dev/null)

    if [[ -z "$all_upstream_files" ]]; then
        echo -e "${RED}Error: No se pudieron obtener archivos de upstream${NC}"
        return 1
    fi

    # Filtrar solo los archivos que coinciden con los patrones de scaffolding
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        for pattern in "${SCAFFOLDING_PATTERNS[@]}"; do
            if [[ "$file" == "$pattern"* ]]; then
                UPSTREAM_FILES+=("$file")
                break
            fi
        done
    done <<< "$all_upstream_files"

    echo -e "${GREEN}+${NC} Encontrados ${#UPSTREAM_FILES[@]} archivos de scaffolding en upstream"
    return 0
}

#######################################
# Verifica si un archivo fue modificado respecto a upstream
#######################################
is_modified_from_upstream() {
    local file="$1"

    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        return 1
    fi

    if git -C "$PROJECT_ROOT" diff --quiet "upstream/$UPSTREAM_BRANCH" -- "$file" 2>/dev/null; then
        return 1  # No modificado
    else
        return 0  # Modificado
    fi
}

#######################################
# Analiza el proyecto comparando con upstream
#######################################
analyze_project() {
    echo -e "${BOLD}Analizando proyecto...${NC}"
    echo ""

    local local_files_in_scaffolding_dirs=()

    # Obtener archivos locales en los directorios de scaffolding
    for pattern in "${SCAFFOLDING_PATTERNS[@]}"; do
        local full_path="$PROJECT_ROOT/$pattern"

        if [[ -d "$full_path" ]]; then
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                local relative_file="${file#$PROJECT_ROOT/}"
                local_files_in_scaffolding_dirs+=("$relative_file")
            done < <(find "$full_path" -type f 2>/dev/null)
        elif [[ -f "$full_path" ]]; then
            local_files_in_scaffolding_dirs+=("$pattern")
        fi
    done

    # Clasificar archivos
    for file in "${local_files_in_scaffolding_dirs[@]}"; do
        local in_upstream=false
        for upstream_file in "${UPSTREAM_FILES[@]}"; do
            if [[ "$file" == "$upstream_file" ]]; then
                in_upstream=true
                break
            fi
        done

        if [[ "$in_upstream" == "true" ]]; then
            BASE_FILES+=("$file")
            if is_modified_from_upstream "$file"; then
                MODIFIED_FILES+=("$file")
            else
                UNMODIFIED_FILES+=("$file")
            fi
        else
            FORK_FILES+=("$file")
        fi
    done
}

#######################################
# Muestra el resumen del analisis
#######################################
show_analysis_summary() {
    echo -e "${BOLD}${CYAN}===============================================${NC}"
    echo -e "${BOLD}${CYAN}  Resumen del Analisis${NC}"
    echo -e "${BOLD}${CYAN}===============================================${NC}"
    echo ""

    # Archivos del fork (protegidos)
    if [[ ${#FORK_FILES[@]} -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}Archivos del FORK detectados (protegidos):${NC}"
        echo -e "  ${GREEN}Total: ${#FORK_FILES[@]} archivos NO seran eliminados${NC}"
        echo ""
    fi

    # Scaffolding base
    echo -e "${BOLD}${BLUE}Scaffolding BASE de Cusco (de upstream):${NC}"
    echo -e "  Total:       ${#BASE_FILES[@]} archivos"
    echo -e "  ${GREEN}Sin cambios: ${#UNMODIFIED_FILES[@]}${NC} (identicos a upstream)"
    echo -e "  ${YELLOW}Modificados: ${#MODIFIED_FILES[@]}${NC} (diferentes de upstream)"
    echo ""

    # Mostrar archivos del fork si verbose
    if [[ "$VERBOSE" == "true" && ${#FORK_FILES[@]} -gt 0 ]]; then
        echo -e "${GREEN}Archivos del fork (protegidos):${NC}"
        for file in "${FORK_FILES[@]}"; do
            echo -e "  ${GREEN}+${NC} $file"
        done
        echo ""
    fi

    # Mostrar archivos modificados
    if [[ ${#MODIFIED_FILES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Archivos base MODIFICADOS localmente:${NC}"
        for file in "${MODIFIED_FILES[@]}"; do
            echo -e "  ${YELLOW}->${NC} $file"
        done
        echo ""
    fi
}

#######################################
# Pregunta principal segun el estado del proyecto
#######################################
ask_main_action() {
    local total_base=${#BASE_FILES[@]}
    local total_modified=${#MODIFIED_FILES[@]}
    local total_fork=${#FORK_FILES[@]}

    echo -e "${CYAN}===============================================${NC}"

    if [[ $total_fork -gt 0 ]]; then
        echo -e "${GREEN}NOTA: $total_fork archivos del fork seran preservados automaticamente.${NC}"
        echo ""
    fi

    if [[ $total_base -eq 0 ]]; then
        echo -e "${GREEN}No hay archivos base de Cusco para eliminar.${NC}"
        echo -e "Parece que el scaffolding ya fue limpiado anteriormente."
        MAIN_ACTION="cancel"
        return
    fi

    if [[ $total_modified -eq 0 ]]; then
        echo -e "${GREEN}Ningun archivo base fue modificado.${NC}"
        echo -e "Todos los archivos base son identicos a upstream."
        echo ""
        echo -e "${BOLD}Que deseas hacer?${NC}"
        echo -e "  ${GREEN}[1]${NC} Eliminar TODO el scaffolding base (recomendado)"
        echo -e "  ${BLUE}[2]${NC} Revisar uno por uno"
        echo -e "  ${RED}[q]${NC} Cancelar"
        echo ""
        echo -n "> "
        read -r response </dev/tty

        case "$response" in
            1) MAIN_ACTION="delete_all" ;;
            2) MAIN_ACTION="review_all" ;;
            q|Q) MAIN_ACTION="cancel" ;;
            *) MAIN_ACTION="cancel" ;;
        esac
    else
        echo -e "${YELLOW}Se detectaron $total_modified archivos base modificados de $total_base totales.${NC}"
        echo ""
        echo -e "${BOLD}Que deseas hacer?${NC}"
        echo -e "  ${GREEN}[1]${NC} Eliminar NO modificados, revisar modificados uno por uno"
        echo -e "  ${BLUE}[2]${NC} Revisar TODO uno por uno"
        echo -e "  ${YELLOW}[3]${NC} Eliminar TODO (incluyendo modificados)"
        echo -e "  ${RED}[q]${NC} Cancelar"
        echo ""
        echo -n "> "
        read -r response </dev/tty

        case "$response" in
            1) MAIN_ACTION="delete_unmodified" ;;
            2) MAIN_ACTION="review_all" ;;
            3) MAIN_ACTION="delete_all" ;;
            q|Q) MAIN_ACTION="cancel" ;;
            *) MAIN_ACTION="cancel" ;;
        esac
    fi
}

#######################################
# Elimina un archivo
#######################################
delete_file() {
    local file="$1"
    local full_path="$PROJECT_ROOT/$file"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Se eliminaria: $file"
        DELETED_COUNT=$((DELETED_COUNT + 1))
        return
    fi

    if [[ -f "$full_path" ]]; then
        rm -f "$full_path"
        DELETED_COUNT=$((DELETED_COUNT + 1))
        echo -e "${GREEN}+${NC} Eliminado: $file"
    fi
}

#######################################
# Muestra el contenido de un archivo
#######################################
show_file_content() {
    local file="$1"
    local full_path="$PROJECT_ROOT/$file"

    echo ""
    echo -e "${CYAN}---------------------------------------------${NC}"
    echo -e "${BOLD}Contenido de: $file${NC}"
    echo -e "${CYAN}---------------------------------------------${NC}"

    if [[ -f "$full_path" ]]; then
        local lines
        lines=$(wc -l < "$full_path")
        head -30 "$full_path"
        if [[ $lines -gt 30 ]]; then
            echo -e "${YELLOW}... ($lines lineas en total)${NC}"
        fi
    else
        echo -e "${RED}Archivo no encontrado${NC}"
    fi
    echo -e "${CYAN}---------------------------------------------${NC}"
    echo ""
}

#######################################
# Muestra diff de un archivo contra upstream
#######################################
show_file_diff() {
    local file="$1"

    echo ""
    echo -e "${CYAN}---------------------------------------------${NC}"
    echo -e "${BOLD}Diferencias con upstream: $file${NC}"
    echo -e "${CYAN}---------------------------------------------${NC}"

    git -C "$PROJECT_ROOT" diff "upstream/$UPSTREAM_BRANCH" -- "$file" 2>/dev/null | head -50

    echo -e "${CYAN}---------------------------------------------${NC}"
    echo ""
}

#######################################
# Pregunta por un archivo individual
#######################################
process_single_file() {
    local file="$1"
    local is_modified="$2"

    local mod_marker=""
    [[ "$is_modified" == "true" ]] && mod_marker="${YELLOW}[modificado]${NC} "

    while true; do
        echo "" >&2
        echo -e "${BOLD}$mod_marker$file${NC}" >&2
        echo -e "  ${GREEN}[e]${NC} Eliminar" >&2
        echo -e "  ${BLUE}[m]${NC} Mantener" >&2
        echo -e "  ${CYAN}[v]${NC} Ver contenido" >&2
        [[ "$is_modified" == "true" ]] && echo -e "  ${YELLOW}[d]${NC} Ver diff con upstream" >&2
        echo -e "  ${RED}[q]${NC} Salir" >&2
        echo -n "> " >&2
        read -r response </dev/tty

        case "$response" in
            e|E)
                delete_file "$file"
                return
                ;;
            m|M)
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                echo -e "${BLUE}->${NC} Mantenido: $file"
                return
                ;;
            v|V)
                show_file_content "$file"
                ;;
            d|D)
                [[ "$is_modified" == "true" ]] && show_file_diff "$file"
                ;;
            q|Q)
                show_summary
                exit 0
                ;;
            *)
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                echo -e "${BLUE}->${NC} Mantenido: $file"
                return
                ;;
        esac
    done
}

#######################################
# Elimina todos los archivos base
#######################################
delete_all_base() {
    echo ""
    echo -e "${BOLD}Eliminando archivos base...${NC}"
    echo -e "${DIM}(Los archivos del fork son preservados automaticamente)${NC}"
    echo ""

    for file in "${BASE_FILES[@]}"; do
        delete_file "$file"
    done
}

#######################################
# Elimina archivos base no modificados
#######################################
delete_unmodified() {
    echo ""
    echo -e "${BOLD}Eliminando archivos base no modificados...${NC}"
    echo ""

    for file in "${UNMODIFIED_FILES[@]}"; do
        delete_file "$file"
    done
}

#######################################
# Revisa archivos modificados uno por uno
#######################################
review_modified() {
    if [[ ${#MODIFIED_FILES[@]} -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}${YELLOW}Revisando archivos modificados...${NC}"
        for file in "${MODIFIED_FILES[@]}"; do
            process_single_file "$file" "true"
        done
    fi
}

#######################################
# Revisa todos los archivos base uno por uno
#######################################
review_all() {
    echo ""
    echo -e "${BOLD}Revisando archivos base...${NC}"

    for file in "${BASE_FILES[@]}"; do
        local is_mod="false"
        for mod in "${MODIFIED_FILES[@]}"; do
            [[ "$mod" == "$file" ]] && is_mod="true" && break
        done
        process_single_file "$file" "$is_mod"
    done
}

#######################################
# Pregunta al usuario que hacer con un archivo auxiliar modificado
#######################################
ask_auxiliary_file_action() {
    local file="$1"
    local description="$2"

    if [[ "$AUTO_YES" == "true" ]]; then
        echo -e "${YELLOW}->${NC} Preservado (modificado): $file"
        return 1
    fi

    while true; do
        echo "" >&2
        echo -e "${YELLOW}[modificado]${NC} ${BOLD}$file${NC}" >&2
        echo -e "  ${DIM}$description${NC}" >&2
        echo -e "  ${GREEN}[s]${NC} Sobrescribir con version limpia" >&2
        echo -e "  ${BLUE}[p]${NC} Preservar contenido del fork" >&2
        echo -e "  ${CYAN}[d]${NC} Ver diferencias con upstream" >&2
        echo -n "> " >&2
        read -r response </dev/tty

        case "$response" in
            s|S)
                return 0
                ;;
            p|P)
                echo -e "${BLUE}->${NC} Preservado: $file"
                return 1
                ;;
            d|D)
                show_file_diff "$file"
                ;;
            *)
                echo -e "${BLUE}->${NC} Preservado: $file"
                return 1
                ;;
        esac
    done
}

#######################################
# Limpia archivos auxiliares del backend
# (app.module.ts, prisma schema, etc.)
#######################################
clean_backend_auxiliary() {
    echo ""
    echo -e "${BOLD}Limpiando archivos auxiliares del backend...${NC}"

    # =====================================================================
    # Limpiar app.module.ts - quitar imports de AuthModule y UsersModule
    # =====================================================================
    local app_module_rel="src/api/src/app.module.ts"
    local app_module="$PROJECT_ROOT/$app_module_rel"
    if [[ -f "$app_module" ]]; then
        local should_clean=true

        if is_modified_from_upstream "$app_module_rel"; then
            if ! ask_auxiliary_file_action "$app_module_rel" "Contiene imports de modulos personalizados"; then
                should_clean=false
            fi
        fi

        if [[ "$should_clean" == "true" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                cat > "$app_module" << 'APPMODULE'
import { Module } from '@nestjs/common';
import { CoreModule } from './core/core.module';

@Module({
  imports: [
    CoreModule,
    // Agrega tus modulos aqui
  ],
})
export class AppModule {}
APPMODULE
            fi
            echo -e "${GREEN}+${NC} Limpiado: $app_module_rel"
        fi
    fi

    # =====================================================================
    # Limpiar prisma/schema.prisma - quitar modelo User y enum Role
    # =====================================================================
    local schema_rel="src/api/prisma/schema.prisma"
    local schema="$PROJECT_ROOT/$schema_rel"
    if [[ -f "$schema" ]]; then
        local should_clean=true

        if is_modified_from_upstream "$schema_rel"; then
            if ! ask_auxiliary_file_action "$schema_rel" "Contiene modelos Prisma personalizados"; then
                should_clean=false
            fi
        fi

        if [[ "$should_clean" == "true" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                cat > "$schema" << 'SCHEMA'
// Cusco - Prisma Schema
// Documentacion: https://pris.ly/d/prisma-schema

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// Agrega tus modelos aqui
// Ejemplo:
//
// model Product {
//   id        Int      @id @default(autoincrement())
//   name      String
//   price     Decimal  @db.Decimal(10, 2)
//   createdAt DateTime @default(now()) @map("created_at")
//   updatedAt DateTime @updatedAt @map("updated_at")
//
//   @@map("products")
// }
SCHEMA
            fi
            echo -e "${GREEN}+${NC} Limpiado: $schema_rel"
        fi
    fi
}

#######################################
# Limpia archivos auxiliares del frontend
# (app.routes.ts, app.config.ts, etc.)
#######################################
clean_frontend_auxiliary() {
    echo ""
    echo -e "${BOLD}Limpiando archivos auxiliares del frontend...${NC}"

    # =====================================================================
    # Limpiar app.routes.ts
    # =====================================================================
    local routes_rel="src/frontend/src/app/app.routes.ts"
    local routes="$PROJECT_ROOT/$routes_rel"
    if [[ -f "$routes" ]]; then
        local should_clean=true

        if is_modified_from_upstream "$routes_rel"; then
            if ! ask_auxiliary_file_action "$routes_rel" "Contiene rutas personalizadas"; then
                should_clean=false
            fi
        fi

        if [[ "$should_clean" == "true" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                cat > "$routes" << 'ROUTES'
import { Routes } from '@angular/router';

export const routes: Routes = [
  // Agrega tus rutas aqui
  // Ejemplo:
  // {
  //   path: 'products',
  //   loadComponent: () => import('./pages/products/products.component')
  //     .then(m => m.ProductsComponent),
  // },
  { path: '**', redirectTo: '' },
];
ROUTES
            fi
            echo -e "${GREEN}+${NC} Limpiado: $routes_rel"
        fi
    fi

    # =====================================================================
    # Limpiar app.config.ts - quitar authInterceptor
    # =====================================================================
    local config_rel="src/frontend/src/app/app.config.ts"
    local config="$PROJECT_ROOT/$config_rel"
    if [[ -f "$config" ]]; then
        local should_clean=true

        if is_modified_from_upstream "$config_rel"; then
            if ! ask_auxiliary_file_action "$config_rel" "Contiene providers personalizados"; then
                should_clean=false
            fi
        fi

        if [[ "$should_clean" == "true" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                cat > "$config" << 'CONFIG'
import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideHttpClient(),
  ],
};
CONFIG
            fi
            echo -e "${GREEN}+${NC} Limpiado: $config_rel"
        fi
    fi
}

#######################################
# Limpia directorios vacios despues de eliminar archivos
#######################################
clean_empty_dirs() {
    echo ""
    echo -e "${BOLD}Limpiando directorios vacios...${NC}"

    local dirs_to_check=(
        "src/api/src/modules/users"
        "src/api/src/modules/auth"
        "src/frontend/src/app/atoms/button"
        "src/frontend/src/app/atoms/input"
        "src/frontend/src/app/molecules/card"
        "src/frontend/src/app/molecules/form-field"
        "src/frontend/src/app/pages/home"
        "src/frontend/src/app/pages/login"
        "src/frontend/src/app/core/guards"
        "src/frontend/src/app/core/interceptors"
        "src/frontend/src/app/core/models"
    )

    for dir in "${dirs_to_check[@]}"; do
        local full_dir="$PROJECT_ROOT/$dir"
        if [[ -d "$full_dir" ]] && [[ -z "$(ls -A "$full_dir" 2>/dev/null)" ]]; then
            if [[ "$DRY_RUN" != "true" ]]; then
                rmdir "$full_dir" 2>/dev/null
                # Intentar limpiar directorios padres si quedan vacios
                local parent
                parent=$(dirname "$full_dir")
                while [[ -d "$parent" ]] && [[ -z "$(ls -A "$parent" 2>/dev/null)" ]] && [[ "$parent" != "$PROJECT_ROOT" ]]; do
                    rmdir "$parent" 2>/dev/null
                    parent=$(dirname "$parent")
                done
            fi
            echo -e "${GREEN}+${NC} Directorio vacio eliminado: $dir"
        fi
    done
}

#######################################
# Personaliza la documentacion (docs/) reemplazando el nombre del scaffold
# por el del fork. Delega en scripts/personalize-docs.sh.
#######################################
personalize_docs() {
    local script="$SCRIPT_DIR/personalize-docs.sh"
    [[ -f "$script" ]] || return 0
    [[ -d "$PROJECT_ROOT/docs" ]] || return 0

    local args=()
    [[ "$DRY_RUN" == "true" ]] && args+=("--dry-run")

    # Modo automatico: autodetecta nombre/slug y reemplaza sin preguntar
    if [[ "$AUTO_YES" == "true" ]]; then
        echo ""
        echo -e "${BOLD}Personalizando documentacion (docs/)...${NC}"
        bash "$script" "${args[@]}" || true
        return 0
    fi

    echo ""
    echo -e "${CYAN}===============================================${NC}"
    echo -e "${BOLD}Personalizar la documentacion de docs/?${NC}"
    echo -e "${DIM}Reemplaza 'Cusco'/'cusco' por el nombre de tu proyecto.${NC}"
    echo -n "Personalizar ahora? [s/N] > "
    read -r resp </dev/tty
    case "$resp" in
        s|S|y|Y) ;;
        *)
            echo -e "${BLUE}->${NC} Documentacion sin cambios."
            echo -e "${DIM}    Podes hacerlo luego con: bash scripts/personalize-docs.sh${NC}"
            return 0
            ;;
    esac

    echo -n "Nombre del proyecto (ej: MiApp) [enter = autodetectar] > "
    read -r pname </dev/tty
    echo -n "Slug en minusculas (ej: miapp) [enter = autodetectar] > "
    read -r pslug </dev/tty

    PROJECT_NAME="${pname}" PROJECT_SLUG="${pslug}" bash "$script" "${args[@]}" || true
}

#######################################
# Muestra el resumen final
#######################################
show_summary() {
    echo ""
    echo -e "${BOLD}${CYAN}===============================================${NC}"
    echo -e "${BOLD}${CYAN}  Resumen Final${NC}"
    echo -e "${BOLD}${CYAN}===============================================${NC}"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN] No se realizaron cambios reales${NC}"
        echo ""
    fi

    echo -e "${GREEN}Eliminados:${NC}  $DELETED_COUNT archivos"
    echo -e "${BLUE}Mantenidos:${NC}  $SKIPPED_COUNT archivos"
    echo -e "${CYAN}Fork:${NC}        ${#FORK_FILES[@]} archivos preservados"

    if [[ $DELETED_COUNT -gt 0 ]]; then
        echo ""
        echo -e "${CYAN}Proximos pasos:${NC}"
        echo "  1. Revisar los cambios: git status"
        echo "  2. Si todo esta bien: git add -A && git commit -m 'chore: clean scaffolding'"
        echo "  3. Reconstruir contenedores: npm run docker:rebuild"
        echo "  4. Ejecutar migraciones: npm run prisma:migrate"
    fi
    echo ""
}

#######################################
# Main
#######################################
main() {
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                echo -e "${RED}Opcion desconocida: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    show_banner

    # Verificar que estamos en un repositorio git
    if ! git -C "$PROJECT_ROOT" rev-parse --git-dir &>/dev/null; then
        echo -e "${RED}Error: No se encontro un repositorio git${NC}"
        exit 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}Modo DRY-RUN activado. No se realizaran cambios.${NC}"
        echo ""
    fi

    # Configurar upstream
    if ! setup_upstream; then
        echo -e "${RED}Error: No se pudo configurar upstream${NC}"
        exit 1
    fi
    echo ""

    # Obtener archivos de scaffolding desde upstream
    if ! get_upstream_scaffolding_files; then
        exit 1
    fi
    echo ""

    # Analizar proyecto
    analyze_project
    show_analysis_summary

    # Modo automatico
    if [[ "$AUTO_YES" == "true" ]]; then
        delete_all_base
        clean_backend_auxiliary
        clean_frontend_auxiliary
        clean_empty_dirs
        personalize_docs
        show_summary
        exit 0
    fi

    # Preguntar que hacer
    ask_main_action

    case "$MAIN_ACTION" in
        "cancel")
            echo -e "${YELLOW}Operacion cancelada.${NC}"
            exit 0
            ;;
        "delete_all")
            delete_all_base
            ;;
        "review_all")
            review_all
            ;;
        "delete_unmodified")
            delete_unmodified
            review_modified
            ;;
    esac

    # Limpiar archivos auxiliares
    clean_backend_auxiliary
    clean_frontend_auxiliary

    # Limpiar directorios vacios
    clean_empty_dirs

    # Personalizar la documentacion con el nombre del fork
    personalize_docs

    # Mostrar resumen
    show_summary
}

main "$@"
