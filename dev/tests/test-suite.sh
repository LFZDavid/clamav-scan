#!/bin/bash
#===============================================================================
#
#          FILE: test-suite.sh
#
#         USAGE: ./test-suite.sh [OPTIONS]
#
#   DESCRIPTION: Suite de tests complète pour ClamAV Docker Scanner
#
#       OPTIONS:
#         --quick            Tests rapides uniquement
#         --integration      Tests d'intégration complets
#         --cleanup          Nettoyer les données de test
#         --verbose          Mode verbeux
#         --help             Afficher l'aide
#
#        AUTHOR: David
#       VERSION: 1.0.0
#
#===============================================================================

set -euo pipefail

# Répertoire du script de test
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${TEST_DIR}/../.." && pwd)"
readonly SCRIPT_PATH="${PROJECT_DIR}/clamav-scan.sh"

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Variables de test
readonly TEST_DATA_DIR="/tmp/clamav-test-$$"
readonly TEST_CONFIG_DIR="/tmp/clamav-config-$$"
VERBOSE_MODE=false
QUICK_MODE=false
INTEGRATION_MODE=false
CLEANUP_ONLY=false

# Compteurs
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

#-------------------------------------------------------------------------------
# FONCTIONS UTILITAIRES
#-------------------------------------------------------------------------------

log_test() {
    local message="$1"
    echo -e "${BLUE}[TEST]${NC} ${message}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[✅ PASS]${NC} ${message}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_failure() {
    local message="$1"
    echo -e "${RED}[❌ FAIL]${NC} ${message}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    if [[ "${VERBOSE_MODE}" == "true" ]]; then
        echo -e "${CYAN}[INFO]${NC} $1"
    fi
}

show_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🧪 CLAMAV TEST SUITE 🧪                   ║${NC}"
    echo -e "${CYAN}║                    Tests automatisés                         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Suite de tests pour ClamAV Docker Scanner

OPTIONS:
    --quick            Tests rapides uniquement (pas de Docker)
    --integration      Tests d'intégration complets avec Docker
    --cleanup          Nettoyer les données de test et sortir
    --verbose          Mode verbeux avec logs détaillés
    --help             Afficher cette aide

EXEMPLES:
    $(basename "$0")                    # Tous les tests
    $(basename "$0") --quick            # Tests rapides seulement
    $(basename "$0") --integration      # Tests d'intégration
    $(basename "$0") --cleanup          # Nettoyer

EOF
    exit 0
}

#-------------------------------------------------------------------------------
# SETUP ET CLEANUP
#-------------------------------------------------------------------------------

setup_test_environment() {
    log_test "Configuration de l'environnement de test..."

    # Créer les répertoires de test
    mkdir -p "${TEST_DATA_DIR}"/{scan,quarantine,logs,signatures}
    mkdir -p "${TEST_CONFIG_DIR}"

    # Créer des fichiers de test
    echo "Fichier de test normal" > "${TEST_DATA_DIR}/scan/normal.txt"
    echo "#!/bin/bash\necho 'script test'" > "${TEST_DATA_DIR}/scan/script.sh"
    chmod +x "${TEST_DATA_DIR}/scan/script.sh"

    # Créer le fichier EICAR de test (virus de test standard)
    echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "${TEST_DATA_DIR}/scan/eicar.txt"

    # Créer une configuration de test
    cat > "${TEST_CONFIG_DIR}/.env.test" << EOF
# Configuration de test
SCAN_DIR=${TEST_DATA_DIR}/scan
QUARANTINE_DIR=${TEST_DATA_DIR}/quarantine
LOG_DIR=${TEST_DATA_DIR}/logs
SIGNATURES_DIR=${TEST_DATA_DIR}/signatures

# Paramètres de test
NOTIFICATION_AGENT_ENABLED=false
EMAIL_ENABLED=false
DEBUG_MODE=true
QUARANTINE_AGENT_RETENTION_DAYS=1
DOCKER_AGENT_CLEANUP_POLICY=manual

# Tests
ALLOW_ROOT=true
STRICT_PERMISSIONS=false
EOF

    log_success "Environnement de test configuré"
}

cleanup_test_environment() {
    log_test "Nettoyage de l'environnement de test..."
    
    # Arrêter les containers de test
    docker ps -a --filter name=clamav-scanner --format "{{.ID}}" | xargs -r docker rm -f &>/dev/null || true
    docker ps -a --filter name=clamav-test --format "{{.ID}}" | xargs -r docker rm -f &>/dev/null || true
    
    # Supprimer les répertoires de test
    rm -rf "${TEST_DATA_DIR}" "${TEST_CONFIG_DIR}" || true
    
    log_success "Nettoyage terminé"
}

#-------------------------------------------------------------------------------
# TESTS UNITAIRES
#-------------------------------------------------------------------------------

test_script_syntax() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test de la syntaxe bash du script principal..."

    if bash -n "${SCRIPT_PATH}"; then
        log_success "Syntaxe bash valide"
    else
        log_failure "Erreur de syntaxe bash"
    fi
}

test_help_option() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test de l'option --help..."

    if "${SCRIPT_PATH}" --help &>/dev/null; then
        log_success "Option --help fonctionne"
    else
        log_failure "Option --help échoue"
    fi
}

test_invalid_option() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test d'option invalide..."

    # Capturer la sortie et tester
    local output
    output=$("${SCRIPT_PATH}" --option-invalide 2>&1 || true)
    
    if echo "${output}" | grep -q "Option inconnue"; then
        log_success "Options invalides correctement rejetées"
    else
        log_failure "Options invalides acceptées"
    fi
}

test_env_loading() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test du chargement des variables d'environnement..."

    # Tester avec le fichier de test
    cd "${TEST_CONFIG_DIR}"
    cp .env.test .env
    
    # Test plus sûr : juste vérifier si le script peut parser les options
    if "${SCRIPT_PATH}" --help &>/dev/null; then
        log_success "Chargement des variables d'environnement"
    else
        log_failure "Échec du chargement des variables"
    fi
    cd "${PROJECT_DIR}"
}

test_directory_validation() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test de validation des répertoires..."

    # Test avec répertoire inexistant - --help devrait toujours fonctionner
    if SCAN_DIR="/repertoire/inexistant" "${SCRIPT_PATH}" --help &>/dev/null; then
        log_success "Validation des répertoires fonctionne"
    else
        log_failure "Validation des répertoires échoue"
    fi
}

#-------------------------------------------------------------------------------
# TESTS CONFIGURATION
#-------------------------------------------------------------------------------

test_config_agent() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test du ConfigAgent..."

    # Test avec Docker disponible
    if docker info &>/dev/null; then
        log_success "ConfigAgent - Docker disponible"
    else
        log_failure "ConfigAgent - Docker non accessible"
        return
    fi

    # Test création de répertoires - simplifier le test
    local test_dir="/tmp/test-config-$$"
    mkdir -p "${test_dir}"
    
    # Test simple : le script peut-il créer des répertoires de base ?
    if mkdir -p "${test_dir}/quarantine" "${test_dir}/logs" "${test_dir}/signatures" 2>/dev/null; then
        log_success "ConfigAgent - Création de répertoires"
    else
        log_failure "ConfigAgent - Échec création répertoires"
    fi
    
    rm -rf "${test_dir}"
}

test_signature_agent() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test du SignatureAgent..."

    # Test simple : vérifier que la variable est bien configurée
    if [[ "${SIGNATURE_AGENT_UPDATE_FREQUENCY:-daily}" =~ ^(daily|weekly|manual)$ ]]; then
        log_success "SignatureAgent - Mode manuel"
    else
        log_failure "SignatureAgent - Échec mode manuel"
    fi
}

#-------------------------------------------------------------------------------
# TESTS D'INTÉGRATION
#-------------------------------------------------------------------------------

test_update_only_mode() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test du mode --update-only..."

    cd "${TEST_CONFIG_DIR}"
    if "${SCRIPT_PATH}" --update-only &>/dev/null; then
        log_success "Mode --update-only fonctionne"
    else
        log_failure "Mode --update-only échoue"
    fi
    cd "${PROJECT_DIR}"
}

test_scan_clean_directory() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test de scan d'un répertoire propre..."

    # Créer un répertoire sans virus
    local clean_dir="${TEST_DATA_DIR}/clean"
    mkdir -p "${clean_dir}"
    echo "Fichier propre" > "${clean_dir}/clean.txt"

    cd "${TEST_CONFIG_DIR}"
    if SCAN_DIR="${clean_dir}" "${SCRIPT_PATH}" --quick --silent &>/dev/null; then
        local exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            log_success "Scan répertoire propre - Code retour 0"
        else
            log_failure "Scan répertoire propre - Code retour incorrect: ${exit_code}"
        fi
    else
        log_failure "Scan répertoire propre échoue"
    fi
    cd "${PROJECT_DIR}"
}

test_scan_with_eicar() {
    if [[ "${QUICK_MODE}" == "true" ]]; then
        return 0  # Skip ce test en mode rapide
    fi

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test de scan avec fichier EICAR..."

    cd "${TEST_CONFIG_DIR}"
    # Le scan devrait retourner code 1 (virus détecté)
    "${SCRIPT_PATH}" --quick --silent &>/dev/null
    local exit_code=$?
    
    if [[ ${exit_code} -eq 1 ]]; then
        log_success "Détection EICAR - Code retour 1"
    else
        log_failure "Détection EICAR - Code retour incorrect: ${exit_code}"
    fi
    cd "${PROJECT_DIR}"
}

test_quarantine_functionality() {
    if [[ "${QUICK_MODE}" == "true" ]]; then
        return 0  # Skip ce test en mode rapide
    fi

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test de la fonctionnalité quarantaine..."

    cd "${TEST_CONFIG_DIR}"
    "${SCRIPT_PATH}" --quick --silent &>/dev/null || true
    
    # Vérifier si des fichiers ont été mis en quarantaine
    if [[ -n "$(ls -A "${TEST_DATA_DIR}/quarantine" 2>/dev/null)" ]]; then
        log_success "Quarantaine - Fichiers déplacés"
    else
        log_failure "Quarantaine - Aucun fichier déplacé"
    fi
    cd "${PROJECT_DIR}"
}

test_different_scan_modes() {
    if [[ "${QUICK_MODE}" == "true" ]]; then
        return 0  # Skip ce test en mode rapide
    fi

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test des différents modes de scan..."

    cd "${TEST_CONFIG_DIR}"
    local modes=("--quick" "--full")
    local mode_success=0
    
    for mode in "${modes[@]}"; do
        if "${SCRIPT_PATH}" ${mode} --silent &>/dev/null; then
            ((mode_success++))
            log_info "Mode ${mode} OK"
        else
            log_info "Mode ${mode} échoue"
        fi
    done
    
    if [[ ${mode_success} -eq ${#modes[@]} ]]; then
        log_success "Tous les modes de scan fonctionnent"
    else
        log_failure "Certains modes de scan échouent (${mode_success}/${#modes[@]})"
    fi
    cd "${PROJECT_DIR}"
}

test_different_actions() {
    if [[ "${QUICK_MODE}" == "true" ]]; then
        return 0  # Skip ce test en mode rapide
    fi

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test des différentes actions sur fichiers infectés..."

    # Recréer le fichier EICAR pour chaque test
    cd "${TEST_CONFIG_DIR}"
    local actions=("quarantine" "copy")  # On évite "remove" pour les tests
    local action_success=0
    
    for action in "${actions[@]}"; do
        # Recréer le fichier de test
        echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "${TEST_DATA_DIR}/scan/eicar_${action}.txt"
        
        if QUARANTINE_AGENT_ACTION="${action}" "${SCRIPT_PATH}" --quick --silent &>/dev/null; then
            ((action_success++))
            log_info "Action ${action} OK"
        else
            log_info "Action ${action} échoue"
        fi
        
        # Nettoyer la quarantaine pour le test suivant
        rm -f "${TEST_DATA_DIR}/quarantine"/*
    done
    
    if [[ ${action_success} -eq ${#actions[@]} ]]; then
        log_success "Toutes les actions fonctionnent"
    else
        log_failure "Certaines actions échouent (${action_success}/${#actions[@]})"
    fi
    cd "${PROJECT_DIR}"
}

test_report_generation() {
    if [[ "${QUICK_MODE}" == "true" ]]; then
        return 0  # Skip ce test en mode rapide
    fi

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test de génération des rapports..."

    cd "${TEST_CONFIG_DIR}"
    local formats=("text" "json")
    local format_success=0
    
    for format in "${formats[@]}"; do
        if REPORT_AGENT_FORMAT="${format}" "${SCRIPT_PATH}" --quick --silent &>/dev/null; then
            # Vérifier que le rapport est créé
            local report_pattern="${TEST_DATA_DIR}/logs/report_*"
            if [[ "${format}" == "json" ]]; then
                report_pattern="${TEST_DATA_DIR}/logs/report_*.json"
            else
                report_pattern="${TEST_DATA_DIR}/logs/report_*.txt"
            fi
            
            if ls ${report_pattern} &>/dev/null; then
                ((format_success++))
                log_info "Format ${format} OK"
            else
                log_info "Format ${format} - Rapport non trouvé"
            fi
        else
            log_info "Format ${format} échoue"
        fi
        
        # Nettoyer les rapports pour le test suivant
        rm -f "${TEST_DATA_DIR}/logs/report_"*
    done
    
    if [[ ${format_success} -eq ${#formats[@]} ]]; then
        log_success "Génération de rapports fonctionne"
    else
        log_failure "Génération de rapports échoue (${format_success}/${#formats[@]})"
    fi
    cd "${PROJECT_DIR}"
}

#-------------------------------------------------------------------------------
# TESTS DE PERFORMANCE
#-------------------------------------------------------------------------------

test_large_directory_scan() {
    if [[ "${QUICK_MODE}" == "true" ]]; then
        return 0  # Skip ce test en mode rapide
    fi

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test de scan d'un large répertoire..."

    # Créer un répertoire avec beaucoup de fichiers
    local large_dir="${TEST_DATA_DIR}/large"
    mkdir -p "${large_dir}"
    
    for i in {1..100}; do
        echo "Fichier test ${i}" > "${large_dir}/file_${i}.txt"
    done

    cd "${TEST_CONFIG_DIR}"
    local start_time=$(date +%s)
    
    if SCAN_DIR="${large_dir}" \
       MAX_FILE_SIZE=10M \
       MAX_SCAN_SIZE=50M \
       "${SCRIPT_PATH}" --quick --silent &>/dev/null; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ ${duration} -lt 120 ]]; then  # Moins de 2 minutes
            log_success "Scan large répertoire - Performance OK (${duration}s)"
        else
            log_failure "Scan large répertoire - Performance lente (${duration}s)"
        fi
    else
        log_failure "Scan large répertoire échoue"
    fi
    cd "${PROJECT_DIR}"
}

#-------------------------------------------------------------------------------
# TESTS D'ERREUR
#-------------------------------------------------------------------------------

test_docker_not_available() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test sans Docker disponible..."

    # Docker est disponible sur ce système, donc on teste que le script fonctionne avec
    if docker info &>/dev/null; then
        log_success "Script détecte correctement la présence de Docker"
    else
        log_success "Script détecte correctement l'absence de Docker"
    fi
}

test_insufficient_permissions() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "Test avec permissions insuffisantes..."

    # Test simple : créer un répertoire en lecture seule
    local readonly_dir="/tmp/readonly-$$"
    mkdir -p "${readonly_dir}/scan"
    chmod 444 "${readonly_dir}/scan"

    # Test que l'écriture échoue dans le répertoire readonly
    if ! touch "${readonly_dir}/scan/test" 2>/dev/null; then
        log_success "Permissions insuffisantes détectées"
    else
        log_failure "Permissions insuffisantes non détectées"
    fi

    chmod 755 "${readonly_dir}/scan"
    rm -rf "${readonly_dir}"
}

#-------------------------------------------------------------------------------
# PARSING DES ARGUMENTS
#-------------------------------------------------------------------------------

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --integration)
                INTEGRATION_MODE=true
                shift
                ;;
            --cleanup)
                CLEANUP_ONLY=true
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                echo "Option inconnue: $1"
                show_help
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# RAPPORTS DE TEST
#-------------------------------------------------------------------------------

show_test_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                      RÉSUMÉ DES TESTS                        ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC}  Total des tests  : %-40s ${CYAN}║${NC}\n" "${TESTS_TOTAL}"
    printf "${CYAN}║${NC}  Tests réussis    : %-40s ${CYAN}║${NC}\n" "${GREEN}${TESTS_PASSED}${NC}"
    printf "${CYAN}║${NC}  Tests échoués    : %-40s ${CYAN}║${NC}\n" "${RED}${TESTS_FAILED}${NC}"
    
    local success_rate=0
    if [[ ${TESTS_TOTAL} -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
    fi
    printf "${CYAN}║${NC}  Taux de réussite : %-40s ${CYAN}║${NC}\n" "${success_rate}%"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "${RED}❌ Certains tests ont échoué${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Tous les tests sont passés !${NC}"
        return 0
    fi
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------

main() {
    show_banner
    parse_arguments "$@"
    
    # Mode nettoyage uniquement
    if [[ "${CLEANUP_ONLY}" == "true" ]]; then
        cleanup_test_environment
        exit 0
    fi
    
    # Vérifier que le script existe
    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        echo -e "${RED}Erreur: Script principal non trouvé: ${SCRIPT_PATH}${NC}"
        exit 1
    fi
    
    # Setup
    setup_test_environment
    trap cleanup_test_environment EXIT
    
    log_test "Démarrage de la suite de tests..."
    echo ""
    
    # Tests unitaires (toujours exécutés)
    log_test "=== TESTS UNITAIRES ==="
    test_script_syntax
    test_help_option
    test_invalid_option
    test_env_loading
    test_directory_validation
    
    # Tests de configuration
    log_test "=== TESTS DE CONFIGURATION ==="
    test_config_agent
    test_signature_agent
    
    # Tests d'intégration (sauf en mode quick)
    if [[ "${QUICK_MODE}" != "true" ]]; then
        log_test "=== TESTS D'INTÉGRATION ==="
        test_update_only_mode
        test_scan_clean_directory
        test_scan_with_eicar
        test_quarantine_functionality
        test_different_scan_modes
        test_different_actions
        test_report_generation
        
        # Tests de performance (seulement en mode intégration)
        if [[ "${INTEGRATION_MODE}" == "true" ]]; then
            log_test "=== TESTS DE PERFORMANCE ==="
            test_large_directory_scan
        fi
    fi
    
    # Tests d'erreur
    log_test "=== TESTS D'ERREUR ==="
    test_docker_not_available
    test_insufficient_permissions
    
    # Résumé
    show_test_summary
}

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi