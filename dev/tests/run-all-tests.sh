#!/bin/bash
#===============================================================================
#
#          FILE: run-all-tests.sh
#
#         USAGE: ./run-all-tests.sh [OPTIONS]
#
#   DESCRIPTION: Lanceur principal pour tous les types de tests
#
#===============================================================================

set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${TEST_DIR}/../.." && pwd)"

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Options
QUICK_MODE=false
PERFORMANCE_MODE=false
AGENTS_MODE=false
VERBOSE_MODE=false
CLEANUP_ONLY=false

show_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           🧪 SUITE COMPLÈTE DE TESTS CLAMAV 🧪               ║${NC}"
    echo -e "${CYAN}║                  Tests automatisés                           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Lanceur principal pour tous les tests ClamAV Scanner

OPTIONS:
    --quick            Tests rapides uniquement
    --performance      Tests de performance uniquement
    --agents           Tests des agents uniquement
    --verbose          Mode verbeux
    --cleanup          Nettoyer et sortir
    --help             Afficher cette aide

EXEMPLES:
    $(basename "$0")                # Tous les tests
    $(basename "$0") --quick        # Tests rapides seulement
    $(basename "$0") --performance  # Tests de performance
    $(basename "$0") --agents       # Tests unitaires agents

STRUCTURE DES TESTS:
    test-suite.sh      - Tests d'intégration complets
    test-agents.sh     - Tests unitaires des agents
    test-performance.sh - Tests de performance

EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --performance)
                PERFORMANCE_MODE=true
                shift
                ;;
            --agents)
                AGENTS_MODE=true
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --cleanup)
                CLEANUP_ONLY=true
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

cleanup_all() {
    echo -e "${BLUE}[CLEANUP]${NC} Nettoyage de tous les environnements de test..."
    
    # Nettoyer les containers de test
    docker ps -a --filter name=clamav-scanner --format "{{.ID}}" | xargs -r docker rm -f &>/dev/null || true
    docker ps -a --filter name=clamav-test --format "{{.ID}}" | xargs -r docker rm -f &>/dev/null || true
    
    # Nettoyer les répertoires temporaires
    rm -rf /tmp/clamav-test-* /tmp/clamav-config-* /tmp/clamav-perf-* 2>/dev/null || true
    
    echo -e "${GREEN}✅ Nettoyage terminé${NC}"
}

run_test_script() {
    local script_name="$1"
    local script_path="${TEST_DIR}/${script_name}"
    local options="$2"
    
    if [[ ! -f "${script_path}" ]]; then
        echo -e "${RED}❌ Script de test non trouvé: ${script_path}${NC}"
        return 1
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ Exécution: $(printf "%-48s" "${script_name}") ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    # Rendre le script exécutable
    chmod +x "${script_path}"
    
    # Exécuter avec gestion des erreurs
    if "${script_path}" ${options}; then
        echo -e "${GREEN}✅ ${script_name} - Tous les tests sont passés${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ ${script_name} - Des tests ont échoué${NC}"
        echo ""
        return 1
    fi
}

check_prerequisites() {
    echo -e "${BLUE}[CHECK]${NC} Vérification des prérequis..."
    
    local missing_tools=()
    
    # Vérifier Docker
    if ! command -v docker &>/dev/null; then
        missing_tools+=("docker")
    fi
    
    # Vérifier bc (pour les tests de performance)
    if ! command -v bc &>/dev/null; then
        missing_tools+=("bc")
    fi
    
    # Vérifier le script principal
    if [[ ! -f "${PROJECT_DIR}/clamav-scan.sh" ]]; then
        echo -e "${RED}❌ Script principal non trouvé: ${PROJECT_DIR}/clamav-scan.sh${NC}"
        return 1
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Outils manquants: ${missing_tools[*]}${NC}"
        echo "Installez les outils manquants:"
        for tool in "${missing_tools[@]}"; do
            case "${tool}" in
                "docker")
                    echo "  - Docker: https://docs.docker.com/get-docker/"
                    ;;
                "bc")
                    echo "  - bc: sudo apt install bc"
                    ;;
            esac
        done
        return 1
    fi
    
    echo -e "${GREEN}✅ Prérequis validés${NC}"
    return 0
}

generate_test_report() {
    local test_results=("$@")
    local total_suites=${#test_results[@]}
    local passed_suites=0
    local failed_suites=0
    
    # Compter les succès/échecs
    for result in "${test_results[@]}"; do
        if [[ "${result}" == "0" ]]; then
            ((passed_suites++))
        else
            ((failed_suites++))
        fi
    done
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    RAPPORT FINAL                             ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC}  Suites de tests  : %-40s ${CYAN}║${NC}\n" "${total_suites}"
    printf "${CYAN}║${NC}  Suites réussies  : %-40s ${CYAN}║${NC}\n" "${GREEN}${passed_suites}${NC}"
    printf "${CYAN}║${NC}  Suites échouées  : %-40s ${CYAN}║${NC}\n" "${RED}${failed_suites}${NC}"
    
    local success_rate=0
    if [[ ${total_suites} -gt 0 ]]; then
        success_rate=$(( (passed_suites * 100) / total_suites ))
    fi
    printf "${CYAN}║${NC}  Taux de réussite : %-40s ${CYAN}║${NC}\n" "${success_rate}%"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ ${failed_suites} -gt 0 ]]; then
        echo -e "${RED}❌ Certaines suites de tests ont échoué${NC}"
        echo "Consultez les logs ci-dessus pour plus de détails"
        return 1
    else
        echo -e "${GREEN}🎉 Toutes les suites de tests sont passées !${NC}"
        echo "Le projet ClamAV Scanner est prêt pour production"
        return 0
    fi
}

main() {
    show_banner
    parse_arguments "$@"
    
    # Mode nettoyage uniquement
    if [[ "${CLEANUP_ONLY}" == "true" ]]; then
        cleanup_all
        exit 0
    fi
    
    # Vérifier les prérequis
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Préparer les options communes
    local common_options=""
    if [[ "${VERBOSE_MODE}" == "true" ]]; then
        common_options="${common_options} --verbose"
    fi
    if [[ "${QUICK_MODE}" == "true" ]]; then
        common_options="${common_options} --quick"
    fi
    
    # Suites de tests à exécuter
    local test_suites=()
    local test_results=()
    
    # Déterminer quels tests exécuter
    if [[ "${AGENTS_MODE}" == "true" ]]; then
        test_suites=("test-agents.sh")
    elif [[ "${PERFORMANCE_MODE}" == "true" ]]; then
        test_suites=("test-performance.sh")
    elif [[ "${QUICK_MODE}" == "true" ]]; then
        test_suites=("test-agents.sh" "test-suite.sh")
    else
        # Tous les tests
        test_suites=("test-agents.sh" "test-suite.sh" "test-performance.sh")
    fi
    
    echo -e "${BLUE}[INFO]${NC} Suites de tests sélectionnées: ${test_suites[*]}"
    echo ""
    
    # Nettoyer avant de commencer
    cleanup_all
    echo ""
    
    # Exécuter chaque suite de tests
    for test_suite in "${test_suites[@]}"; do
        local suite_options="${common_options}"
        
        # Options spécifiques par suite
        case "${test_suite}" in
            "test-agents.sh")
                suite_options="${suite_options} all"
                ;;
            "test-suite.sh")
                if [[ "${QUICK_MODE}" == "true" ]]; then
                    suite_options="${suite_options} --quick"
                else
                    suite_options="${suite_options} --integration"
                fi
                ;;
        esac
        
        # Exécuter la suite
        # Nettoyer les espaces en début/fin des options
        suite_options="$(echo "${suite_options}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        
        if run_test_script "${test_suite}" "${suite_options}"; then
            test_results+=(0)
        else
            test_results+=(1)
        fi
        
        # Pause entre les suites
        sleep 2
    done
    
    # Nettoyage final
    cleanup_all
    echo ""
    
    # Rapport final
    generate_test_report "${test_results[@]}"
}

# Gestion propre des signaux
trap cleanup_all EXIT ERR INT TERM

# Rendre tous les scripts de test exécutables
chmod +x "${TEST_DIR}"/*.sh 2>/dev/null || true

# Exécution
main "$@"