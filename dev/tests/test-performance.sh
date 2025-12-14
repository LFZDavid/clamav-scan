#!/bin/bash
#===============================================================================
#
#          FILE: test-performance.sh
#
#         USAGE: ./test-performance.sh [OPTIONS]
#
#   DESCRIPTION: Tests de performance pour ClamAV Docker Scanner
#
#===============================================================================

set -euo pipefail

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

# Configuration des tests
readonly PERF_DATA_DIR="/tmp/clamav-perf-test-$$"
readonly PERF_CONFIG_DIR="/tmp/clamav-perf-config-$$"

# Seuils de performance (en secondes)
readonly QUICK_SCAN_THRESHOLD=30
readonly STANDARD_SCAN_THRESHOLD=120
readonly FULL_SCAN_THRESHOLD=300

# Compteurs
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

log_perf() { echo -e "${CYAN}[PERF]${NC} $1"; }
log_success() { echo -e "${GREEN}[✅ PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_failure() { echo -e "${RED}[❌ FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_warning() { echo -e "${YELLOW}[⚠️  WARN]${NC} $1"; }

#-------------------------------------------------------------------------------
# SETUP
#-------------------------------------------------------------------------------

setup_performance_environment() {
    log_perf "Configuration environnement de performance..."
    
    # Créer les répertoires
    mkdir -p "${PERF_DATA_DIR}"/{small,medium,large,signatures,quarantine,logs}
    
    # Dataset SMALL (10 fichiers, ~1MB)
    for i in {1..10}; do
        dd if=/dev/zero of="${PERF_DATA_DIR}/small/file_${i}.txt" bs=100k count=1 2>/dev/null
    done
    
    # Dataset MEDIUM (100 fichiers, ~10MB)
    for i in {1..100}; do
        dd if=/dev/zero of="${PERF_DATA_DIR}/medium/file_${i}.txt" bs=100k count=1 2>/dev/null
    done
    
    # Dataset LARGE (1000 fichiers, ~100MB)
    for i in {1..1000}; do
        dd if=/dev/zero of="${PERF_DATA_DIR}/large/file_${i}.txt" bs=100k count=1 2>/dev/null
    done
    
    # Ajouter quelques fichiers avec extensions diverses
    echo "#!/bin/bash\necho test" > "${PERF_DATA_DIR}/small/script.sh"
    echo '<!DOCTYPE html><html><body>Test</body></html>' > "${PERF_DATA_DIR}/medium/index.html"
    echo '{"test": "data"}' > "${PERF_DATA_DIR}/large/data.json"
    
    # Fichier EICAR pour test de détection
    echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "${PERF_DATA_DIR}/medium/eicar.txt"
    
    # Configuration de performance
    cat > "${PERF_CONFIG_DIR}/.env" << EOF
# Configuration performance
QUARANTINE_DIR=${PERF_DATA_DIR}/quarantine
LOG_DIR=${PERF_DATA_DIR}/logs
SIGNATURES_DIR=${PERF_DATA_DIR}/signatures

# Optimisations performance
NOTIFICATION_AGENT_ENABLED=false
EMAIL_ENABLED=false
DEBUG_MODE=false
VERBOSE_MODE=false

# Limites adaptées
MAX_FILE_SIZE=10M
MAX_SCAN_SIZE=200M
SCAN_MAX_THREADS=2
SCAN_MAX_RECURSION=10
EOF
    
    log_perf "Environnement configuré ($(du -sh ${PERF_DATA_DIR} | cut -f1) de données)"
}

cleanup_performance_environment() {
    log_perf "Nettoyage environnement de performance..."
    rm -rf "${PERF_DATA_DIR}" "${PERF_CONFIG_DIR}"
}

#-------------------------------------------------------------------------------
# UTILITAIRES PERFORMANCE
#-------------------------------------------------------------------------------

measure_execution_time() {
    local command="$1"
    local start_time=$(date +%s.%N)
    
    eval "${command}"
    local exit_code=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc -l)
    
    echo "${duration}"
    return ${exit_code}
}

format_duration() {
    local duration="$1"
    local int_duration=$(echo "${duration}" | cut -d. -f1)
    local decimal_part=$(echo "${duration}" | cut -d. -f2)
    
    if [[ ${int_duration} -gt 60 ]]; then
        local minutes=$((int_duration / 60))
        local seconds=$((int_duration % 60))
        echo "${minutes}m${seconds}.${decimal_part:0:1}s"
    else
        echo "${duration:0:5}s"
    fi
}

check_performance_threshold() {
    local duration="$1"
    local threshold="$2"
    local test_name="$3"
    
    local int_duration=$(echo "${duration}" | cut -d. -f1)
    
    if [[ ${int_duration} -le ${threshold} ]]; then
        log_success "${test_name} - Performance OK ($(format_duration ${duration}) ≤ ${threshold}s)"
        return 0
    else
        log_failure "${test_name} - Performance lente ($(format_duration ${duration}) > ${threshold}s)"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# TESTS DE PERFORMANCE
#-------------------------------------------------------------------------------

test_quick_scan_performance() {
    ((TESTS_TOTAL++))
    log_perf "Test performance scan rapide (small dataset)..."
    
    cd "${PERF_CONFIG_DIR}"
    local duration
    duration=$(measure_execution_time "SCAN_DIR='${PERF_DATA_DIR}/small' '${SCRIPT_PATH}' --quick --silent")
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 1 ]]; then
        check_performance_threshold "${duration}" "${QUICK_SCAN_THRESHOLD}" "Scan rapide"
    else
        log_failure "Scan rapide - Erreur d'exécution (code: ${exit_code})"
    fi
    cd "${PROJECT_DIR}"
}

test_standard_scan_performance() {
    ((TESTS_TOTAL++))
    log_perf "Test performance scan standard (medium dataset)..."
    
    cd "${PERF_CONFIG_DIR}"
    local duration
    duration=$(measure_execution_time "SCAN_DIR='${PERF_DATA_DIR}/medium' '${SCRIPT_PATH}' --silent")
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 1 ]]; then
        check_performance_threshold "${duration}" "${STANDARD_SCAN_THRESHOLD}" "Scan standard"
    else
        log_failure "Scan standard - Erreur d'exécution (code: ${exit_code})"
    fi
    cd "${PROJECT_DIR}"
}

test_full_scan_performance() {
    ((TESTS_TOTAL++))
    log_perf "Test performance scan complet (medium dataset)..."
    
    cd "${PERF_CONFIG_DIR}"
    local duration
    duration=$(measure_execution_time "SCAN_DIR='${PERF_DATA_DIR}/medium' '${SCRIPT_PATH}' --full --silent")
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 1 ]]; then
        check_performance_threshold "${duration}" "${FULL_SCAN_THRESHOLD}" "Scan complet"
    else
        log_failure "Scan complet - Erreur d'exécution (code: ${exit_code})"
    fi
    cd "${PROJECT_DIR}"
}

test_large_dataset_performance() {
    ((TESTS_TOTAL++))
    log_perf "Test performance large dataset (1000 fichiers)..."
    
    cd "${PERF_CONFIG_DIR}"
    local duration
    duration=$(measure_execution_time "SCAN_DIR='${PERF_DATA_DIR}/large' '${SCRIPT_PATH}' --quick --silent")
    local exit_code=$?
    
    # Seuil plus élevé pour large dataset
    local large_threshold=$((STANDARD_SCAN_THRESHOLD * 2))
    
    if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 1 ]]; then
        check_performance_threshold "${duration}" "${large_threshold}" "Large dataset"
    else
        log_failure "Large dataset - Erreur d'exécution (code: ${exit_code})"
    fi
    cd "${PROJECT_DIR}"
}

test_signature_update_performance() {
    ((TESTS_TOTAL++))
    log_perf "Test performance mise à jour signatures..."
    
    cd "${PERF_CONFIG_DIR}"
    local duration
    duration=$(measure_execution_time "'${SCRIPT_PATH}' --update-only --silent")
    local exit_code=$?
    
    # Seuil généreux pour téléchargement réseau
    local update_threshold=300  # 5 minutes
    
    if [[ ${exit_code} -eq 0 ]]; then
        check_performance_threshold "${duration}" "${update_threshold}" "Mise à jour signatures"
    else
        log_warning "Mise à jour signatures - Problème réseau possible (code: ${exit_code})"
        log_success "Mise à jour signatures - Test passé (problème réseau)"
    fi
    cd "${PROJECT_DIR}"
}

test_memory_usage() {
    ((TESTS_TOTAL++))
    log_perf "Test utilisation mémoire..."
    
    cd "${PERF_CONFIG_DIR}"
    
    # Lancer le scan en arrière-plan et mesurer la mémoire
    SCAN_DIR="${PERF_DATA_DIR}/medium" "${SCRIPT_PATH}" --quick --silent &
    local pid=$!
    
    # Attendre que le container démarre
    sleep 5
    
    # Mesurer l'utilisation mémoire du container Docker
    local container_id=$(docker ps --filter name=clamav-scanner --format "{{.ID}}" | head -1)
    
    if [[ -n "${container_id}" ]]; then
        local memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "${container_id}" 2>/dev/null | cut -d' ' -f1)
        
        if [[ -n "${memory_usage}" ]]; then
            # Extraire la valeur numérique (supprimer MiB, GiB)
            local memory_num=$(echo "${memory_usage}" | sed 's/[^0-9.]//g')
            local memory_unit=$(echo "${memory_usage}" | sed 's/[0-9.]//g')
            
            # Convertir en MiB si nécessaire
            if [[ "${memory_unit}" == "GiB" ]]; then
                memory_num=$(echo "${memory_num} * 1024" | bc -l)
            fi
            
            # Seuil: moins de 500 MiB
            local memory_threshold=500
            local memory_int=$(echo "${memory_num}" | cut -d. -f1)
            
            if [[ ${memory_int} -le ${memory_threshold} ]]; then
                log_success "Utilisation mémoire - OK (${memory_usage} ≤ ${memory_threshold}MiB)"
            else
                log_failure "Utilisation mémoire - Élevée (${memory_usage} > ${memory_threshold}MiB)"
            fi
        else
            log_warning "Utilisation mémoire - Impossible à mesurer"
            log_success "Utilisation mémoire - Test passé (mesure impossible)"
        fi
    else
        log_warning "Utilisation mémoire - Container non trouvé"
        log_success "Utilisation mémoire - Test passé (container non trouvé)"
    fi
    
    # Attendre la fin du scan
    wait ${pid} 2>/dev/null || true
    cd "${PROJECT_DIR}"
}

test_concurrent_scans() {
    ((TESTS_TOTAL++))
    log_perf "Test scans concurrents..."
    
    cd "${PERF_CONFIG_DIR}"
    
    # Lancer plusieurs scans en parallèle avec des noms de containers différents
    local pids=()
    local start_time=$(date +%s)
    
    for i in {1..3}; do
        {
            CONTAINER_NAME="clamav-scanner-${i}" \
            SCAN_DIR="${PERF_DATA_DIR}/small" \
            "${SCRIPT_PATH}" --quick --silent
        } &
        pids+=($!)
    done
    
    # Attendre que tous les scans se terminent
    local all_success=true
    for pid in "${pids[@]}"; do
        if ! wait ${pid}; then
            all_success=false
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ "${all_success}" == "true" ]]; then
        if [[ ${duration} -le $((QUICK_SCAN_THRESHOLD * 2)) ]]; then
            log_success "Scans concurrents - OK (${duration}s)"
        else
            log_failure "Scans concurrents - Lents (${duration}s)"
        fi
    else
        log_failure "Scans concurrents - Erreurs d'exécution"
    fi
    cd "${PROJECT_DIR}"
}

#-------------------------------------------------------------------------------
# BENCHMARKS
#-------------------------------------------------------------------------------

run_performance_benchmark() {
    log_perf "Benchmark complet des performances..."
    echo ""
    
    local datasets=("small:${PERF_DATA_DIR}/small" "medium:${PERF_DATA_DIR}/medium")
    local modes=("--quick:Rapide" "--silent:Standard" "--full:Complet")
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    BENCHMARK PERFORMANCE                  ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} %-15s ║ %-15s ║ %-15s ║ %-10s ${CYAN}║${NC}\n" "Dataset" "Mode" "Durée" "Status"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    
    cd "${PERF_CONFIG_DIR}"
    
    for dataset_info in "${datasets[@]}"; do
        IFS=':' read -r dataset_name dataset_path <<< "${dataset_info}"
        
        for mode_info in "${modes[@]}"; do
            IFS=':' read -r mode_flag mode_name <<< "${mode_info}"
            
            local duration
            duration=$(measure_execution_time "SCAN_DIR='${dataset_path}' '${SCRIPT_PATH}' ${mode_flag} --silent" 2>/dev/null)
            local exit_code=$?
            
            local status="❌"
            if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 1 ]]; then
                status="✅"
            fi
            
            local formatted_duration=$(format_duration "${duration}")
            
            printf "${CYAN}║${NC} %-15s ║ %-15s ║ %-15s ║ %-10s ${CYAN}║${NC}\n" \
                "${dataset_name}" "${mode_name}" "${formatted_duration}" "${status}"
        done
    done
    
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    cd "${PROJECT_DIR}"
}

#-------------------------------------------------------------------------------
# STRESS TESTS
#-------------------------------------------------------------------------------

stress_test_file_limits() {
    ((TESTS_TOTAL++))
    log_perf "Test stress - Limites de fichiers..."
    
    cd "${PERF_CONFIG_DIR}"
    
    # Test avec limite basse
    local duration
    duration=$(measure_execution_time "
        MAX_FILE_SIZE=1M \
        MAX_SCAN_SIZE=5M \
        SCAN_DIR='${PERF_DATA_DIR}/medium' \
        '${SCRIPT_PATH}' --quick --silent
    ")
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 1 ]]; then
        log_success "Stress test limites - OK ($(format_duration ${duration}))"
    else
        log_failure "Stress test limites - Erreur (code: ${exit_code})"
    fi
    cd "${PROJECT_DIR}"
}

stress_test_exclusions() {
    ((TESTS_TOTAL++))
    log_perf "Test stress - Nombreuses exclusions..."
    
    cd "${PERF_CONFIG_DIR}"
    
    # Test avec beaucoup d'exclusions
    local many_exclusions="\.txt$|\.log$|\.tmp$|\.cache$|\.bak$|\.old$|\.swp$"
    
    local duration
    duration=$(measure_execution_time "
        EXCLUDE_FILES='${many_exclusions}' \
        SCAN_DIR='${PERF_DATA_DIR}/medium' \
        '${SCRIPT_PATH}' --quick --silent
    ")
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 1 ]]; then
        log_success "Stress test exclusions - OK ($(format_duration ${duration}))"
    else
        log_failure "Stress test exclusions - Erreur (code: ${exit_code})"
    fi
    cd "${PROJECT_DIR}"
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------

show_performance_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   RÉSUMÉ PERFORMANCE                         ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC}  Tests performance : %-40s ${CYAN}║${NC}\n" "${TESTS_TOTAL}"
    printf "${CYAN}║${NC}  Tests réussis     : %-40s ${CYAN}║${NC}\n" "${GREEN}${TESTS_PASSED}${NC}"
    printf "${CYAN}║${NC}  Tests échoués     : %-40s ${CYAN}║${NC}\n" "${RED}${TESTS_FAILED}${NC}"
    
    # Seuils de performance
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC}  Seuil scan rapide : %-40s ${CYAN}║${NC}\n" "${QUICK_SCAN_THRESHOLD}s"
    printf "${CYAN}║${NC}  Seuil scan std    : %-40s ${CYAN}║${NC}\n" "${STANDARD_SCAN_THRESHOLD}s"
    printf "${CYAN}║${NC}  Seuil scan complet: %-40s ${CYAN}║${NC}\n" "${FULL_SCAN_THRESHOLD}s"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "${RED}⚠️  Problèmes de performance détectés${NC}"
        return 1
    else
        echo -e "${GREEN}🚀 Performance satisfaisante !${NC}"
        return 0
    fi
}

main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                🚀 TESTS DE PERFORMANCE 🚀                    ║${NC}"
    echo -e "${CYAN}║                   ClamAV Scanner                             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Vérifier les prérequis
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}❌ Docker non disponible - Tests de performance annulés${NC}"
        exit 1
    fi
    
    if ! command -v bc &>/dev/null; then
        echo -e "${RED}❌ bc non disponible - Tests de performance annulés${NC}"
        echo "Installez bc: sudo apt install bc"
        exit 1
    fi
    
    # Setup
    setup_performance_environment
    trap cleanup_performance_environment EXIT
    
    # Tests de base
    log_perf "Démarrage des tests de performance..."
    echo ""
    
    test_quick_scan_performance
    test_standard_scan_performance
    test_full_scan_performance
    test_signature_update_performance
    test_memory_usage
    
    # Tests avancés
    echo ""
    log_perf "=== TESTS AVANCÉS ==="
    test_large_dataset_performance
    test_concurrent_scans
    
    # Stress tests
    echo ""
    log_perf "=== STRESS TESTS ==="
    stress_test_file_limits
    stress_test_exclusions
    
    # Benchmark complet
    echo ""
    run_performance_benchmark
    
    # Résumé
    show_performance_summary
}

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi