#!/bin/bash
#===============================================================================
#
#          FILE: clamav-scan.sh
#
#         USAGE: ./clamav-scan.sh [OPTIONS]
#
#   DESCRIPTION: Script d'analyse antivirus avec ClamAV dans Docker
#                Architecture basée sur des agents modulaires
#
#       OPTIONS:
#         -d, --directory    Répertoire à scanner (défaut: configuré dans .env)
#         -f, --full         Scan complet (plus lent, plus approfondi)
#         -q, --quick        Scan rapide (fichiers basiques uniquement)
#         -r, --remove       Supprimer les fichiers infectés
#         -m, --move         Déplacer vers quarantaine (défaut)
#         -u, --update-only  Mettre à jour les signatures uniquement
#         -s, --silent       Mode silencieux
#         -v, --verbose      Mode verbeux
#         -h, --help         Afficher l'aide
#
#        AUTHOR: David
#       VERSION: 2.0.0
#       CREATED: $(date +%Y-%m-%d)
#
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION ET CHARGEMENT DES VARIABLES
#-------------------------------------------------------------------------------

# Répertoire du script
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs pour les logs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Chargement de la configuration
load_env_config() {
    local env_files=("${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env" "${SCRIPT_DIR}/.env.local")
    
    for env_file in "${env_files[@]}"; do
        if [[ -f "${env_file}" ]]; then
            log_debug "Chargement de ${env_file}"
            set -a  # Export automatique
            source "${env_file}"
            set +a
        fi
    done
}

# Chargement initial de la config
load_env_config

# Variables par défaut avec fallback
readonly SCAN_DIR="${SCAN_DIR:-/data}"
readonly QUARANTINE_DIR="${QUARANTINE_DIR:-/var/clamav/quarantine}"
readonly LOG_DIR="${LOG_DIR:-/var/log/clamav}"
readonly SIGNATURES_DIR="${SIGNATURES_DIR:-/var/lib/clamav}"

readonly CONTAINER_NAME="${CONTAINER_NAME:-clamav-scanner}"
readonly DOCKER_IMAGE="${DOCKER_IMAGE:-clamav/clamav:latest}"

# Fichiers de log avec timestamp
readonly DATE_FORMAT=$(date +"%Y-%m-%d_%H-%M-%S")
readonly SCAN_LOG="${LOG_DIR}/scan_${DATE_FORMAT}.log"
readonly REPORT_FILE="${LOG_DIR}/report_${DATE_FORMAT}.txt"

# Options par défaut
SCAN_MODE="${SCANNER_AGENT_DEFAULT_MODE:-standard}"
ACTION_MODE="${QUARANTINE_AGENT_ACTION:-quarantine}"
VERBOSE_MODE="${CONFIG_AGENT_VERBOSE:-false}"
SILENT_MODE=false
UPDATE_ONLY=false

#-------------------------------------------------------------------------------
# FONCTIONS UTILITAIRES ET LOGGING
#-------------------------------------------------------------------------------

log_debug() {
    if [[ "${DEBUG_MODE:-false}" == "true" ]] || [[ "${VERBOSE_MODE}" == "true" ]]; then
        local message="$1"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${PURPLE}[DEBUG]${NC} ${timestamp} - ${message}"
        echo "[DEBUG] ${timestamp} - ${message}" >> "${SCAN_LOG}" 2>/dev/null || true
    fi
}

log_info() {
    if [[ "${SILENT_MODE}" == "false" ]]; then
        local message="$1"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${BLUE}[INFO]${NC} ${timestamp} - ${message}"
    fi
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${SCAN_LOG}" 2>/dev/null || true
}

log_success() {
    if [[ "${SILENT_MODE}" == "false" ]]; then
        local message="$1"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${GREEN}[SUCCESS]${NC} ${timestamp} - ${message}"
    fi
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${SCAN_LOG}" 2>/dev/null || true
}

log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARNING]${NC} ${timestamp} - ${message}" >&2
    echo "[WARNING] ${timestamp} - ${message}" >> "${SCAN_LOG}" 2>/dev/null || true
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} ${timestamp} - ${message}" >&2
    echo "[ERROR] ${timestamp} - ${message}" >> "${SCAN_LOG}" 2>/dev/null || true
}

show_banner() {
    if [[ "${SILENT_MODE}" == "false" ]]; then
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            🛡️  CLAMAV ANTIVIRUS SCANNER 🛡️                   ║${NC}"
        echo -e "${CYAN}║                      Version 2.0.0                           ║${NC}"
        echo -e "${CYAN}║                   Architecture Agents                        ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Script d'analyse antivirus avec ClamAV dans Docker - Architecture Agents

OPTIONS:
    -d, --directory DIR    Répertoire à scanner (défaut: ${SCAN_DIR})
    -f, --full             Scan complet et approfondi 
    -q, --quick            Scan rapide (fichiers basiques)
    -r, --remove           Supprimer les fichiers infectés
    -m, --move             Déplacer vers quarantaine (défaut)
    -u, --update-only      Mettre à jour les signatures uniquement
    -s, --silent           Mode silencieux
    -v, --verbose          Mode verbeux avec logs détaillés  
    -h, --help             Afficher cette aide

MODES DE SCAN:
    standard               Scan équilibré (défaut)
    full                   Scan complet (archives, PDF, emails)
    quick                  Scan rapide (fichiers de base)

ACTIONS SUR FICHIERS INFECTÉS:
    quarantine            Déplacer vers quarantaine (récupérable)
    remove                Supprimer définitivement (irréversible)
    copy                  Copier vers quarantaine (garder original)

EXEMPLES:
    $(basename "$0")                        # Scan standard par défaut
    $(basename "$0") -d /home -f            # Scan complet de /home
    $(basename "$0") -d /var/www -r         # Scan avec suppression
    $(basename "$0") --update-only          # MAJ signatures seulement
    $(basename "$0") -q -s                  # Scan rapide silencieux

VARIABLES D'ENVIRONNEMENT:
    Voir le fichier .env.example pour la configuration complète

FICHIERS:
    ${SCAN_LOG}     # Log détaillé
    ${REPORT_FILE}  # Rapport final

EOF
    exit 0
}

#-------------------------------------------------------------------------------
# AGENT CONFIGURATION - Validation et prérequis
#-------------------------------------------------------------------------------

config_agent_validate() {
    log_info "[ConfigAgent] Validation des prérequis système..."

    # Vérifier si Docker est installé
    if ! command -v docker &> /dev/null; then
        log_error "[ConfigAgent] Docker n'est pas installé"
        exit 1
    fi

    # Vérifier si Docker daemon fonctionne
    if ! docker info &> /dev/null; then
        log_error "[ConfigAgent] Docker daemon n'est pas accessible"
        log_error "Essayez: sudo systemctl start docker"
        exit 1
    fi

    # Vérifier les permissions root
    if [[ "${ALLOW_ROOT:-false}" == "false" ]] && [[ $EUID -eq 0 ]]; then
        log_error "[ConfigAgent] Exécution en root non autorisée"
        log_error "Définissez ALLOW_ROOT=true dans .env pour forcer"
        exit 1
    fi

    log_debug "[ConfigAgent] Docker version: $(docker --version)"
    log_success "[ConfigAgent] Prérequis Docker validés"
}

config_agent_create_directories() {
    log_info "[ConfigAgent] Création/vérification des répertoires..."

    local dirs=("${QUARANTINE_DIR}" "${LOG_DIR}" "${SIGNATURES_DIR}")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            log_info "[ConfigAgent] Création: ${dir}"
            mkdir -p "${dir}"
            
            if [[ "${STRICT_PERMISSIONS:-true}" == "true" ]]; then
                chmod 750 "${dir}"
                log_debug "[ConfigAgent] Permissions définies: 750 pour ${dir}"
            fi
        else
            log_debug "[ConfigAgent] Répertoire existant: ${dir}"
        fi
    done

    # Vérifier que le répertoire à scanner existe
    if [[ ! -d "${SCAN_DIR}" ]]; then
        log_error "[ConfigAgent] Le répertoire à scanner n'existe pas: ${SCAN_DIR}"
        exit 1
    fi

    log_success "[ConfigAgent] Répertoires validés"
}

#-------------------------------------------------------------------------------
# AGENT SIGNATURES - Mise à jour des définitions antivirus
#-------------------------------------------------------------------------------

signature_agent_update() {
    log_info "[SignatureAgent] Vérification des signatures antivirus..."

    # Vérifier si une mise à jour est nécessaire
    local update_needed=false
    local frequency="${SIGNATURE_AGENT_UPDATE_FREQUENCY:-daily}"
    
    if [[ "${frequency}" == "manual" ]]; then
        log_info "[SignatureAgent] Mode manuel - pas de mise à jour automatique"
        return 0
    fi

    # Vérifier l'âge des signatures existantes
    if [[ -f "${SIGNATURES_DIR}/daily.cvd" ]]; then
        local file_age=$(( $(date +%s) - $(stat -c %Y "${SIGNATURES_DIR}/daily.cvd" 2>/dev/null || echo 0) ))
        local max_age=86400  # 24h par défaut
        
        case "${frequency}" in
            "weekly") max_age=604800 ;;  # 7 jours
            "daily"|*) max_age=86400 ;;  # 24h
        esac
        
        if [[ ${file_age} -gt ${max_age} ]]; then
            update_needed=true
            log_info "[SignatureAgent] Signatures obsolètes (${file_age}s > ${max_age}s)"
        fi
    else
        update_needed=true
        log_info "[SignatureAgent] Aucune signature trouvée"
    fi

    if [[ "${update_needed}" == "true" ]] || [[ "${SIGNATURE_AGENT_AUTO_UPDATE:-true}" == "true" ]]; then
        log_info "[SignatureAgent] Mise à jour des signatures..."
        
        docker run --rm \
            --name "${CONTAINER_NAME}-update" \
            -v "${SIGNATURES_DIR}:/var/lib/clamav" \
            ${VERBOSE_DOCKER:+--log-driver json-file} \
            "${DOCKER_IMAGE}" \
            freshclam --verbose

        local exit_code=$?
        
        if [[ ${exit_code} -eq 0 ]]; then
            log_success "[SignatureAgent] Signatures mises à jour avec succès"
        else
            log_warning "[SignatureAgent] Problème lors de la mise à jour (code: ${exit_code})"
            # Ne pas arrêter le script, continuer avec les anciennes signatures
        fi
        
        return ${exit_code}
    else
        log_info "[SignatureAgent] Signatures à jour"
        return 0
    fi
}

#-------------------------------------------------------------------------------
# AGENT DOCKER - Gestion des containers
#-------------------------------------------------------------------------------

docker_agent_pull_image() {
    log_info "[DockerAgent] Vérification de l'image Docker..."
    
    local pull_policy="${DOCKER_PULL_POLICY:-missing}"
    local should_pull=false
    
    case "${pull_policy}" in
        "always")
            should_pull=true
            ;;
        "missing")
            if ! docker image inspect "${DOCKER_IMAGE}" &> /dev/null; then
                should_pull=true
            fi
            ;;
        "never")
            should_pull=false
            ;;
    esac
    
    if [[ "${should_pull}" == "true" ]]; then
        log_info "[DockerAgent] Téléchargement de ${DOCKER_IMAGE}..."
        docker pull "${DOCKER_IMAGE}"
        log_success "[DockerAgent] Image téléchargée"
    else
        log_debug "[DockerAgent] Image Docker déjà présente"
    fi
}

docker_agent_cleanup() {
    log_info "[DockerAgent] Nettoyage des containers existants..."
    
    # Arrêter les containers existants avec le même nom
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "[DockerAgent] Arrêt du container existant: ${CONTAINER_NAME}"
        docker stop "${CONTAINER_NAME}" &> /dev/null || true
        docker rm "${CONTAINER_NAME}" &> /dev/null || true
    fi
    
    # Nettoyage selon la politique définie
    local cleanup_policy="${DOCKER_AGENT_CLEANUP_POLICY:-auto}"
    
    case "${cleanup_policy}" in
        "aggressive")
            log_info "[DockerAgent] Nettoyage agressif des containers orphelins..."
            docker container prune -f &> /dev/null || true
            ;;
        "auto")
            # Nettoyer seulement les containers liés à ClamAV
            docker ps -a --filter "ancestor=${DOCKER_IMAGE}" --format "{{.ID}}" | \
                xargs -r docker rm -f &> /dev/null || true
            ;;
        "manual")
            log_debug "[DockerAgent] Nettoyage manuel - aucune action automatique"
            ;;
    esac
    
    log_success "[DockerAgent] Nettoyage terminé"
}

#-------------------------------------------------------------------------------
# AGENT SCANNER - Orchestration du scan antivirus
#-------------------------------------------------------------------------------

scanner_agent_build_options() {
    log_info "[ScannerAgent] Configuration des options de scan (mode: ${SCAN_MODE})..."

    # Options de base
    SCAN_OPTIONS=(
        "--recursive"
        "--infected"
        "--log=/logs/clamscan.log"
        "--max-filesize=${MAX_FILE_SIZE:-100M}"
        "--max-scansize=${MAX_SCAN_SIZE:-500M}"
    )

    # Action sur les fichiers infectés
    case "${ACTION_MODE}" in
        "remove")
            SCAN_OPTIONS+=("--remove=yes")
            log_warning "[ScannerAgent] ⚠️  Mode SUPPRESSION - Les fichiers infectés seront SUPPRIMÉS"
            ;;
        "quarantine"|"move")
            SCAN_OPTIONS+=("--move=/quarantine")
            log_info "[ScannerAgent] 📦 Mode QUARANTAINE activé"
            ;;
        "copy")
            SCAN_OPTIONS+=("--copy=/quarantine")
            log_info "[ScannerAgent] 📋 Mode COPIE activé"
            ;;
    esac

    # Options selon le mode de scan
    case "${SCAN_MODE}" in
        "full")
            SCAN_OPTIONS+=(
                "--scan-pdf=yes"
                "--scan-html=yes" 
                "--scan-mail=yes"
                "--scan-archive=yes"
                "--scan-ole2=yes"
            )
            if [[ "${SCAN_ENCRYPTED_ARCHIVES:-false}" == "true" ]]; then
                SCAN_OPTIONS+=("--alert-encrypted=yes")
            fi
            log_info "[ScannerAgent] Mode COMPLET: PDF, HTML, emails, archives"
            ;;
        "quick")
            SCAN_OPTIONS+=(
                "--scan-archive=no"
                "--scan-mail=no"
                "--max-recursion=5"
            )
            log_info "[ScannerAgent] Mode RAPIDE: fichiers basiques uniquement"
            ;;
        "standard"|*)
            log_info "[ScannerAgent] Mode STANDARD: équilibré"
            ;;
    esac

    # Exclusions
    if [[ -n "${EXCLUDE_DIRS:-}" ]]; then
        IFS='|' read -ra ADDR <<< "${EXCLUDE_DIRS}"
        for exclude in "${ADDR[@]}"; do
            SCAN_OPTIONS+=("--exclude-dir=${exclude}")
            log_debug "[ScannerAgent] Exclusion répertoire: ${exclude}"
        done
    fi

    # Limites avancées
    if [[ -n "${SCAN_MAX_FILES:-}" ]]; then
        SCAN_OPTIONS+=("--max-files=${SCAN_MAX_FILES}")
    fi
    
    if [[ -n "${SCAN_MAX_RECURSION:-}" ]]; then
        SCAN_OPTIONS+=("--max-recursion=${SCAN_MAX_RECURSION}")
    fi

    log_success "[ScannerAgent] Options configurées: ${#SCAN_OPTIONS[@]} paramètres"
}

scanner_agent_execute() {
    log_info "[ScannerAgent] Démarrage de l'analyse antivirus..."
    log_info "[ScannerAgent] Répertoire: ${SCAN_DIR}"
    log_info "[ScannerAgent] Quarantaine: ${QUARANTINE_DIR}"
    
    local scan_start=$(date +%s)
    
    # Construction des options
    scanner_agent_build_options

    # Lancement du container pour le scan
    local docker_run_options=(
        "--rm"
        "--name" "${CONTAINER_NAME}"
        "-v" "${SCAN_DIR}:/scandir:ro"
        "-v" "${QUARANTINE_DIR}:/quarantine"
        "-v" "${LOG_DIR}:/logs"
        "-v" "${SIGNATURES_DIR}:/var/lib/clamav:ro"
    )

    # Options de debug Docker
    if [[ "${VERBOSE_DOCKER:-false}" == "true" ]]; then
        docker_run_options+=("--log-driver" "json-file")
    fi

    # Timeout si configuré
    if [[ -n "${SCAN_TIMEOUT:-}" ]]; then
        timeout "${SCAN_TIMEOUT}" docker run "${docker_run_options[@]}" \
            "${DOCKER_IMAGE}" clamscan "${SCAN_OPTIONS[@]}" /scandir
    else
        docker run "${docker_run_options[@]}" \
            "${DOCKER_IMAGE}" clamscan "${SCAN_OPTIONS[@]}" /scandir
    fi

    local scan_exit_code=$?
    local scan_end=$(date +%s)
    SCAN_DURATION=$((scan_end - scan_start))

    case ${scan_exit_code} in
        0)
            log_success "[ScannerAgent] ✅ Scan terminé - Aucun virus détecté"
            ;;
        1)
            log_warning "[ScannerAgent] 🦠 Scan terminé - Virus détectés!"
            ;;
        *)
            log_error "[ScannerAgent] ❌ Erreur lors du scan (code: ${scan_exit_code})"
            ;;
    esac

    log_info "[ScannerAgent] Durée: ${SCAN_DURATION} secondes"
    return ${scan_exit_code}
}

#-------------------------------------------------------------------------------
# AGENT QUARANTINE - Gestion des fichiers infectés
#-------------------------------------------------------------------------------

quarantine_agent_process() {
    log_info "[QuarantineAgent] Traitement de la quarantaine..."

    # Compter les fichiers en quarantaine
    QUARANTINE_COUNT=0
    if [[ -d "${QUARANTINE_DIR}" ]]; then
        QUARANTINE_COUNT=$(find "${QUARANTINE_DIR}" -type f -newer "${SCAN_LOG}" 2>/dev/null | wc -l)
    fi

    if [[ ${QUARANTINE_COUNT} -gt 0 ]]; then
        log_warning "[QuarantineAgent] ${QUARANTINE_COUNT} fichier(s) traité(s)"
        
        # Lister les fichiers si en mode verbose
        if [[ "${VERBOSE_MODE}" == "true" ]]; then
            log_info "[QuarantineAgent] Fichiers en quarantaine:"
            find "${QUARANTINE_DIR}" -type f -newer "${SCAN_LOG}" 2>/dev/null | \
                while read -r file; do
                    log_info "  - $(basename "${file}")"
                done
        fi
    else
        log_success "[QuarantineAgent] Aucun fichier à traiter"
    fi

    # Nettoyage automatique selon la rétention
    quarantine_agent_cleanup
}

quarantine_agent_cleanup() {
    local retention_days="${QUARANTINE_AGENT_RETENTION_DAYS:-7}"
    local auto_cleanup="${QUARANTINE_AGENT_AUTO_CLEANUP:-true}"
    
    if [[ "${auto_cleanup}" == "true" ]] && [[ ${retention_days} -gt 0 ]]; then
        log_info "[QuarantineAgent] Nettoyage automatique (> ${retention_days} jours)..."
        
        local old_files_count
        old_files_count=$(find "${QUARANTINE_DIR}" -type f -mtime "+${retention_days}" 2>/dev/null | wc -l)
        
        if [[ ${old_files_count} -gt 0 ]]; then
            find "${QUARANTINE_DIR}" -type f -mtime "+${retention_days}" -delete 2>/dev/null || true
            log_info "[QuarantineAgent] ${old_files_count} ancien(s) fichier(s) supprimé(s)"
        else
            log_debug "[QuarantineAgent] Aucun ancien fichier à nettoyer"
        fi
    fi
}

#-------------------------------------------------------------------------------
# AGENT RAPPORT - Génération des rapports
#-------------------------------------------------------------------------------

report_agent_generate() {
    local exit_code=$1
    local duration=$2
    
    log_info "[ReportAgent] Génération du rapport..."

    # Déterminer le statut
    local status=""
    local status_icon=""
    case ${exit_code} in
        0)
            status="CLEAN"
            status_icon="✅"
            ;;
        1)
            status="INFECTED"
            status_icon="🦠"
            ;;
        *)
            status="ERROR"
            status_icon="❌"
            ;;
    esac

    # Format selon configuration
    local format="${REPORT_AGENT_FORMAT:-text}"
    
    case "${format}" in
        "json")
            report_agent_generate_json "${exit_code}" "${status}" "${duration}"
            ;;
        "html")
            report_agent_generate_html "${exit_code}" "${status}" "${duration}" 
            ;;
        "text"|*)
            report_agent_generate_text "${exit_code}" "${status}" "${status_icon}" "${duration}"
            ;;
    esac

    log_success "[ReportAgent] Rapport généré: ${REPORT_FILE}"
    
    # Afficher le résumé si pas en mode silencieux
    if [[ "${SILENT_MODE}" == "false" ]]; then
        report_agent_show_summary "${status}" "${status_icon}" "${duration}"
    fi
}

report_agent_generate_text() {
    local exit_code=$1
    local status=$2
    local status_icon=$3
    local duration=$4
    
    cat > "${REPORT_FILE}" << EOF
================================================================================
                      RAPPORT D'ANALYSE ANTIVIRUS CLAMAV
================================================================================

${status_icon} STATUT: ${status}

📅 Date d'analyse     : $(date '+%Y-%m-%d %H:%M:%S')
📂 Répertoire scanné  : ${SCAN_DIR}
⏱️  Durée de l'analyse : ${duration} secondes
🔧 Mode de scan       : ${SCAN_MODE}
🛡️  Action infectés   : ${ACTION_MODE}
🦠 Fichiers infectés  : ${QUARANTINE_COUNT}
📦 Quarantaine        : ${QUARANTINE_DIR}

--------------------------------------------------------------------------------
                              CONFIGURATION
--------------------------------------------------------------------------------

Image Docker          : ${DOCKER_IMAGE}
Signatures             : ${SIGNATURES_DIR}
Logs                   : ${LOG_DIR}
Exclusions             : ${EXCLUDE_DIRS:-aucune}

--------------------------------------------------------------------------------
                               DÉTAILS DU SCAN
--------------------------------------------------------------------------------

$(if [[ -f "${LOG_DIR}/clamscan.log" ]]; then cat "${LOG_DIR}/clamscan.log"; else echo "Log détaillé non disponible"; fi)

--------------------------------------------------------------------------------
                        FICHIERS EN QUARANTAINE
--------------------------------------------------------------------------------

$(if [[ -d "${QUARANTINE_DIR}" ]] && [[ ${QUARANTINE_COUNT} -gt 0 ]]; then
    ls -la "${QUARANTINE_DIR}"
else
    echo "Aucun fichier en quarantaine"
fi)

================================================================================
                          FIN DU RAPPORT
================================================================================
EOF
}

report_agent_generate_json() {
    local exit_code=$1
    local status=$2
    local duration=$3
    
    cat > "${REPORT_FILE%.txt}.json" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "scanner": {
    "name": "ClamAV Docker Scanner",
    "version": "2.0.0",
    "mode": "${SCAN_MODE}",
    "action": "${ACTION_MODE}"
  },
  "scan": {
    "exit_code": ${exit_code},
    "status": "${status}",
    "duration_seconds": ${duration},
    "directory": "${SCAN_DIR}",
    "quarantine_count": ${QUARANTINE_COUNT}
  },
  "paths": {
    "quarantine": "${QUARANTINE_DIR}",
    "logs": "${LOG_DIR}",
    "signatures": "${SIGNATURES_DIR}"
  },
  "docker": {
    "image": "${DOCKER_IMAGE}",
    "container": "${CONTAINER_NAME}"
  }
}
EOF
    log_info "[ReportAgent] Rapport JSON: ${REPORT_FILE%.txt}.json"
}

report_agent_show_summary() {
    local status=$1
    local status_icon=$2
    local duration=$3
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    RÉSUMÉ DE L'ANALYSE                       ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC}  Statut           : %-40s ${CYAN}║${NC}\n" "${status_icon} ${status}"
    printf "${CYAN}║${NC}  Durée            : %-40s ${CYAN}║${NC}\n" "${duration} secondes"
    printf "${CYAN}║${NC}  Fichiers infectés: %-40s ${CYAN}║${NC}\n" "${QUARANTINE_COUNT}"
    printf "${CYAN}║${NC}  Mode scan        : %-40s ${CYAN}║${NC}\n" "${SCAN_MODE}"
    printf "${CYAN}║${NC}  Action           : %-40s ${CYAN}║${NC}\n" "${ACTION_MODE}"
    printf "${CYAN}║${NC}  Rapport          : %-40s ${CYAN}║${NC}\n" "$(basename "${REPORT_FILE}")"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# AGENT NOTIFICATION - Alertes et notifications  
#-------------------------------------------------------------------------------

notification_agent_send() {
    local exit_code=$1
    
    if [[ "${NOTIFICATION_AGENT_ENABLED:-false}" != "true" ]]; then
        log_debug "[NotificationAgent] Notifications désactivées"
        return 0
    fi

    log_info "[NotificationAgent] Envoi des notifications..."

    # Notification email
    if [[ "${EMAIL_ENABLED:-false}" == "true" ]]; then
        notification_agent_send_email "${exit_code}"
    fi

    # Extensions futures: Slack, Discord, webhooks...
    log_success "[NotificationAgent] Notifications envoyées"
}

notification_agent_send_email() {
    local exit_code=$1
    
    log_info "[NotificationAgent] Envoi email vers ${EMAIL_TO}..."

    local subject_prefix="${EMAIL_SUBJECT_PREFIX:-[ClamAV]}"
    local subject=""
    
    case ${exit_code} in
        0) subject="${subject_prefix} ✅ Analyse OK - Aucun virus détecté" ;;
        1) subject="${subject_prefix} 🦠 ALERTE - Virus détecté!" ;;
        *) subject="${subject_prefix} ❌ Erreur lors de l'analyse" ;;
    esac

    if command -v mail &> /dev/null; then
        {
            echo "Rapport d'analyse ClamAV"
            echo "========================"
            echo ""
            echo "Statut: $([ ${exit_code} -eq 0 ] && echo "CLEAN" || echo "INFECTED/ERROR")"
            echo "Fichiers infectés: ${QUARANTINE_COUNT}"
            echo "Durée: ${SCAN_DURATION} secondes"
            echo "Répertoire: ${SCAN_DIR}"
            echo ""
            echo "Rapport complet: ${REPORT_FILE}"
        } | mail -s "${subject}" "${EMAIL_TO}"
        
        log_success "[NotificationAgent] Email envoyé à ${EMAIL_TO}"
    else
        log_warning "[NotificationAgent] Commande 'mail' non disponible"
    fi
}

#-------------------------------------------------------------------------------
# NETTOYAGE ET FINALISATION
#-------------------------------------------------------------------------------

cleanup_and_finalize() {
    log_info "Finalisation et nettoyage..."
    
    # Nettoyage Docker selon la politique
    if [[ "${KEEP_CONTAINERS:-false}" != "true" ]]; then
        docker_agent_cleanup
    fi
    
    # Supprimer les anciens logs selon la rétention
    find "${LOG_DIR}" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find "${LOG_DIR}" -name "*.txt" -mtime +30 -delete 2>/dev/null || true
    
    log_success "Nettoyage terminé"
}

#-------------------------------------------------------------------------------
# PARSING DES ARGUMENTS
#-------------------------------------------------------------------------------

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--directory)
                SCAN_DIR="$2"
                shift 2
                ;;
            -f|--full)
                SCAN_MODE="full"
                shift
                ;;
            -q|--quick)
                SCAN_MODE="quick"
                shift
                ;;
            -r|--remove)
                ACTION_MODE="remove"
                shift
                ;;
            -m|--move)
                ACTION_MODE="quarantine"
                shift
                ;;
            -u|--update-only)
                UPDATE_ONLY=true
                shift
                ;;
            -s|--silent)
                SILENT_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# MAIN - Orchestration des agents
#-------------------------------------------------------------------------------

main() {
    local start_time=$(date +%s)
    
    # Affichage de la bannière
    show_banner

    # Parsing des arguments
    parse_arguments "$@"

    # Mode mise à jour uniquement
    if [[ "${UPDATE_ONLY}" == "true" ]]; then
        config_agent_validate
        config_agent_create_directories
        docker_agent_pull_image
        signature_agent_update
        exit $?
    fi

    # Exécution séquentielle des agents
    log_info "🚀 Démarrage de l'orchestration des agents..."

    # 1. Agent Configuration
    config_agent_validate
    config_agent_create_directories

    # 2. Agent Docker  
    docker_agent_pull_image
    docker_agent_cleanup

    # 3. Agent Signatures
    signature_agent_update

    # 4. Agent Scanner
    scanner_agent_execute
    local scan_exit_code=$?

    # 5. Agent Quarantine
    quarantine_agent_process

    # Calcul du temps total
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    # 6. Agent Rapport
    report_agent_generate ${scan_exit_code} ${total_duration}

    # 7. Agent Notification
    notification_agent_send ${scan_exit_code}

    # Finalisation
    cleanup_and_finalize

    log_success "🎉 Orchestration terminée en ${total_duration} secondes"
    
    # Code de sortie
    exit ${scan_exit_code}
}

# Gestion des signaux pour nettoyage propre
trap cleanup_and_finalize EXIT ERR INT TERM

# Exécution
main "$@"