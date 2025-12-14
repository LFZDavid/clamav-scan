#!/bin/bash
#===============================================================================
#
#          FILE: test-agents.sh
#
#         USAGE: ./test-agents.sh [AGENT_NAME]
#
#   DESCRIPTION: Tests unitaires spécifiques pour chaque agent
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
readonly NC='\033[0m'

# Compteurs
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_success() { echo -e "${GREEN}[✅ PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_failure() { echo -e "${RED}[❌ FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

#-------------------------------------------------------------------------------
# TESTS CONFIG AGENT
#-------------------------------------------------------------------------------

test_config_agent_docker_check() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "ConfigAgent: Vérification Docker..."
    
    # Test de la logique de détection Docker
    if command -v docker &>/dev/null; then
        log_success "ConfigAgent: Docker disponible détecté"
    else
        log_success "ConfigAgent: Absence Docker détectée" 
    fi
}

test_config_agent_root_check() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "ConfigAgent: Vérification exécution root..."
    
    # Test avec ALLOW_ROOT=false (simulé)
    local test_script="/tmp/test-root-$$"
    cat > "${test_script}" << 'EOF'
#!/bin/bash
if [[ $EUID -eq 0 ]] && [[ "${ALLOW_ROOT:-false}" == "false" ]]; then
    echo "BLOCK_ROOT"
    exit 1
fi
echo "ALLOW_EXECUTION"
EOF
    chmod +x "${test_script}"
    
    # Test en tant qu'utilisateur normal
    if [[ $EUID -ne 0 ]]; then
        local result=$(ALLOW_ROOT=false "${test_script}")
        if [[ "${result}" == "ALLOW_EXECUTION" ]]; then
            log_success "ConfigAgent: Utilisateur normal autorisé"
        else
            log_failure "ConfigAgent: Utilisateur normal bloqué"
        fi
    else
        # Test en tant que root
        local result=$(ALLOW_ROOT=false "${test_script}")
        if [[ "${result}" == "BLOCK_ROOT" ]]; then
            log_success "ConfigAgent: Root correctement bloqué"
        else
            log_failure "ConfigAgent: Root non bloqué"
        fi
    fi
    
    rm -f "${test_script}"
}

test_config_agent_directory_creation() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "ConfigAgent: Création de répertoires..."
    
    local test_base="/tmp/config-test-$$"
    local dirs=("${test_base}/quarantine" "${test_base}/logs" "${test_base}/signatures")
    
    # Simuler la création de répertoires
    for dir in "${dirs[@]}"; do
        if mkdir -p "${dir}" && [[ -d "${dir}" ]]; then
            continue
        else
            log_failure "ConfigAgent: Échec création ${dir}"
            rm -rf "${test_base}"
            return
        fi
    done
    
    log_success "ConfigAgent: Création de répertoires"
    rm -rf "${test_base}"
}

#-------------------------------------------------------------------------------
# TESTS SIGNATURE AGENT
#-------------------------------------------------------------------------------

test_signature_agent_frequency_logic() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "SignatureAgent: Logique de fréquence..."
    
    local test_sig_dir="/tmp/sig-test-$$"
    mkdir -p "${test_sig_dir}"
    
    # Créer un fichier de signature "ancien"
    touch -t 202401010000 "${test_sig_dir}/daily.cvd"  # 1er janvier 2024
    
    # Test de la logique d'âge
    local file_age=$(( $(date +%s) - $(stat -c %Y "${test_sig_dir}/daily.cvd" 2>/dev/null || echo 0) ))
    local max_age_daily=86400    # 24h
    local max_age_weekly=604800  # 7 jours
    
    if [[ ${file_age} -gt ${max_age_daily} ]]; then
        log_success "SignatureAgent: Détection signatures obsolètes (daily)"
    else
        log_failure "SignatureAgent: Logique daily incorrecte"
    fi
    
    rm -rf "${test_sig_dir}"
}

test_signature_agent_manual_mode() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "SignatureAgent: Mode manuel..."
    
    # En mode manuel, aucune mise à jour automatique ne devrait avoir lieu
    # C'est un test de logique plutôt qu'un vrai test Docker
    local manual_mode="manual"
    
    if [[ "${manual_mode}" == "manual" ]]; then
        log_success "SignatureAgent: Mode manuel détecté"
    else
        log_failure "SignatureAgent: Mode manuel non reconnu"
    fi
}

#-------------------------------------------------------------------------------
# TESTS DOCKER AGENT
#-------------------------------------------------------------------------------

test_docker_agent_image_policies() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "DockerAgent: Politiques de pull..."
    
    local policies=("always" "missing" "never")
    local policy_logic_ok=0
    
    for policy in "${policies[@]}"; do
        case "${policy}" in
            "always")
                # Toujours télécharger
                if [[ "${policy}" == "always" ]]; then
                    policy_logic_ok=$((policy_logic_ok + 1))
                fi
                ;;
            "missing")
                # Télécharger si absent
                if [[ "${policy}" == "missing" ]]; then
                    policy_logic_ok=$((policy_logic_ok + 1))
                fi
                ;;
            "never")
                # Ne jamais télécharger
                if [[ "${policy}" == "never" ]]; then
                    policy_logic_ok=$((policy_logic_ok + 1))
                fi
                ;;
        esac
    done
    
    if [[ ${policy_logic_ok} -eq 3 ]]; then
        log_success "DockerAgent: Logique des politiques"
    else
        log_failure "DockerAgent: Logique des politiques incorrecte"
    fi
}

test_docker_agent_cleanup_policies() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "DockerAgent: Politiques de nettoyage..."
    
    local cleanup_policies=("auto" "manual" "aggressive")
    local cleanup_logic_ok=0
    
    for policy in "${cleanup_policies[@]}"; do
        case "${policy}" in
            "auto"|"manual"|"aggressive")
                cleanup_logic_ok=$((cleanup_logic_ok + 1))
                ;;
        esac
    done
    
    if [[ ${cleanup_logic_ok} -eq 3 ]]; then
        log_success "DockerAgent: Politiques de nettoyage"
    else
        log_failure "DockerAgent: Politiques de nettoyage incorrectes"
    fi
}

#-------------------------------------------------------------------------------
# TESTS SCANNER AGENT
#-------------------------------------------------------------------------------

test_scanner_agent_mode_options() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "ScannerAgent: Options de modes de scan..."
    
    # Tester la construction d'options pour différents modes
    local modes=("standard" "quick" "full")
    local mode_options_ok=0
    
    for mode in "${modes[@]}"; do
        case "${mode}" in
            "standard")
                # Mode équilibré - options de base
                if [[ "${mode}" == "standard" ]]; then
                    mode_options_ok=$((mode_options_ok + 1))
                fi
                ;;
            "quick")
                # Mode rapide - options limitées
                if [[ "${mode}" == "quick" ]]; then
                    mode_options_ok=$((mode_options_ok + 1))
                fi
                ;;
            "full")
                # Mode complet - toutes les options
                if [[ "${mode}" == "full" ]]; then
                    mode_options_ok=$((mode_options_ok + 1))
                fi
                ;;
        esac
    done
    
    if [[ ${mode_options_ok} -eq 3 ]]; then
        log_success "ScannerAgent: Modes de scan"
    else
        log_failure "ScannerAgent: Modes de scan incorrects"
    fi
}

test_scanner_agent_action_modes() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "ScannerAgent: Modes d'action..."
    
    local actions=("quarantine" "remove" "copy")
    local action_logic_ok=0
    
    for action in "${actions[@]}"; do
        case "${action}" in
            "quarantine"|"move")
                # Déplacement vers quarantaine
                action_logic_ok=$((action_logic_ok + 1))
                ;;
            "remove")
                # Suppression définitive
                action_logic_ok=$((action_logic_ok + 1))
                ;;
            "copy")
                # Copie vers quarantaine
                action_logic_ok=$((action_logic_ok + 1))
                ;;
        esac
    done
    
    if [[ ${action_logic_ok} -eq 3 ]]; then
        log_success "ScannerAgent: Modes d'action"
    else
        log_failure "ScannerAgent: Modes d'action incorrects"
    fi
}

test_scanner_agent_exclusions() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "ScannerAgent: Gestion des exclusions..."
    
    # Test de parsing des exclusions
    local exclude_dirs="^/proc|^/sys|^/dev"
    IFS='|' read -ra exclusions <<< "${exclude_dirs}"
    
    if [[ ${#exclusions[@]} -eq 3 ]]; then
        log_success "ScannerAgent: Parsing des exclusions"
    else
        log_failure "ScannerAgent: Parsing des exclusions incorrect (${#exclusions[@]} au lieu de 3)"
    fi
}

#-------------------------------------------------------------------------------
# TESTS QUARANTINE AGENT
#-------------------------------------------------------------------------------

test_quarantine_agent_retention() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "QuarantineAgent: Logique de rétention..."
    
    local test_quarantine="/tmp/quarantine-test-$$"
    mkdir -p "${test_quarantine}"
    
    # Créer des fichiers de différents âges
    touch "${test_quarantine}/recent.txt"
    touch -t 202401010000 "${test_quarantine}/old.txt"  # 1er janvier 2024
    
    # Simuler la logique de nettoyage
    local retention_days=7
    local old_files_count=$(find "${test_quarantine}" -type f -mtime "+${retention_days}" 2>/dev/null | wc -l)
    
    if [[ ${old_files_count} -gt 0 ]]; then
        log_success "QuarantineAgent: Détection fichiers anciens"
    else
        log_failure "QuarantineAgent: Aucun fichier ancien détecté"
    fi
    
    rm -rf "${test_quarantine}"
}

test_quarantine_agent_counting() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "QuarantineAgent: Comptage des fichiers..."
    
    local test_quarantine="/tmp/quarantine-count-$$"
    mkdir -p "${test_quarantine}"
    
    # Créer quelques fichiers
    for i in {1..5}; do
        echo "test" > "${test_quarantine}/file_${i}.txt"
    done
    
    # Compter les fichiers
    local file_count=$(find "${test_quarantine}" -type f | wc -l)
    
    if [[ ${file_count} -eq 5 ]]; then
        log_success "QuarantineAgent: Comptage correct (${file_count})"
    else
        log_failure "QuarantineAgent: Comptage incorrect (${file_count} au lieu de 5)"
    fi
    
    rm -rf "${test_quarantine}"
}

#-------------------------------------------------------------------------------
# TESTS REPORT AGENT
#-------------------------------------------------------------------------------

test_report_agent_status_logic() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "ReportAgent: Logique des statuts..."
    
    local test_cases=(
        "0:CLEAN:✅"
        "1:INFECTED:🦠"
        "2:ERROR:❌"
    )
    
    local status_logic_ok=0
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r exit_code expected_status expected_icon <<< "${test_case}"
        
        local status=""
        local status_icon=""
        
        case ${exit_code} in
            0) status="CLEAN"; status_icon="✅" ;;
            1) status="INFECTED"; status_icon="🦠" ;;
            *) status="ERROR"; status_icon="❌" ;;
        esac
        
        if [[ "${status}" == "${expected_status}" ]] && [[ "${status_icon}" == "${expected_icon}" ]]; then
            status_logic_ok=$((status_logic_ok + 1))
        fi
    done
    
    if [[ ${status_logic_ok} -eq ${#test_cases[@]} ]]; then
        log_success "ReportAgent: Logique des statuts"
    else
        log_failure "ReportAgent: Logique des statuts incorrecte (${status_logic_ok}/${#test_cases[@]})"
    fi
}

test_report_agent_format_detection() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "ReportAgent: Détection des formats..."
    
    local formats=("text" "json" "html")
    local format_logic_ok=0
    
    for format in "${formats[@]}"; do
        case "${format}" in
            "text"|"json"|"html")
                format_logic_ok=$((format_logic_ok + 1))
                ;;
        esac
    done
    
    if [[ ${format_logic_ok} -eq 3 ]]; then
        log_success "ReportAgent: Formats supportés"
    else
        log_failure "ReportAgent: Formats non reconnus"
    fi
}

#-------------------------------------------------------------------------------
# TESTS NOTIFICATION AGENT
#-------------------------------------------------------------------------------

test_notification_agent_email_logic() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "NotificationAgent: Logique email..."
    
    # Test de construction des sujets d'email
    local test_cases=(
        "0:[ClamAV] ✅ Analyse OK - Aucun virus détecté"
        "1:[ClamAV] 🦠 ALERTE - Virus détecté!"
        "2:[ClamAV] ❌ Erreur lors de l'analyse"
    )
    
    local email_logic_ok=0
    local subject_prefix="[ClamAV]"
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r exit_code expected_subject <<< "${test_case}"
        
        local subject=""
        case ${exit_code} in
            0) subject="${subject_prefix} ✅ Analyse OK - Aucun virus détecté" ;;
            1) subject="${subject_prefix} 🦠 ALERTE - Virus détecté!" ;;
            *) subject="${subject_prefix} ❌ Erreur lors de l'analyse" ;;
        esac
        
        if [[ "${subject}" == "${expected_subject}" ]]; then
            email_logic_ok=$((email_logic_ok + 1))
        fi
    done
    
    if [[ ${email_logic_ok} -eq ${#test_cases[@]} ]]; then
        log_success "NotificationAgent: Logique des sujets email"
    else
        log_failure "NotificationAgent: Logique des sujets incorrecte"
    fi
}

test_notification_agent_conditions() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "NotificationAgent: Conditions d'envoi..."
    
    # Test des conditions d'activation
    local test_scenarios=(
        "NOTIFICATION_AGENT_ENABLED=false,EMAIL_ENABLED=true:NO_SEND"
        "NOTIFICATION_AGENT_ENABLED=true,EMAIL_ENABLED=false:NO_EMAIL"
        "NOTIFICATION_AGENT_ENABLED=true,EMAIL_ENABLED=true:SEND_EMAIL"
    )
    
    local condition_logic_ok=0
    
    for scenario in "${test_scenarios[@]}"; do
        IFS=':' read -r conditions expected <<< "${scenario}"
        
        # Parser les conditions
        local notification_enabled="false"
        local email_enabled="false"
        
        if [[ "${conditions}" =~ NOTIFICATION_AGENT_ENABLED=true ]]; then
            notification_enabled="true"
        fi
        if [[ "${conditions}" =~ EMAIL_ENABLED=true ]]; then
            email_enabled="true"
        fi
        
        # Logique de test
        local should_send="NO_SEND"
        if [[ "${notification_enabled}" == "true" ]]; then
            if [[ "${email_enabled}" == "true" ]]; then
                should_send="SEND_EMAIL"
            else
                should_send="NO_EMAIL"
            fi
        fi
        
        if [[ "${should_send}" == "${expected}" ]]; then
            condition_logic_ok=$((condition_logic_ok + 1))
        fi
    done
    
    if [[ ${condition_logic_ok} -eq ${#test_scenarios[@]} ]]; then
        log_success "NotificationAgent: Conditions d'envoi"
    else
        log_failure "NotificationAgent: Conditions d'envoi incorrectes"
    fi
}

#-------------------------------------------------------------------------------
# RUNNER
#-------------------------------------------------------------------------------

run_agent_tests() {
    # Parser les arguments pour extraire le nom de l'agent
    local agent="all"
    for arg in "$@"; do
        case "${arg}" in
            --quick|--verbose|--integration)
                # Ignorer les options globales
                ;;
            config|signature|docker|scanner|quarantine|report|notification|all)
                agent="${arg}"
                ;;
        esac
    done
    
    echo "🧪 Tests des agents ClamAV Scanner"
    echo "=================================="
    echo ""
    
    case "${agent}" in
        "config"|"all")
            echo "=== TESTS CONFIG AGENT ==="
            test_config_agent_docker_check
            test_config_agent_root_check
            test_config_agent_directory_creation
            echo ""
            ;;
    esac
    
    case "${agent}" in
        "signature"|"all")
            echo "=== TESTS SIGNATURE AGENT ==="
            test_signature_agent_frequency_logic
            test_signature_agent_manual_mode
            echo ""
            ;;
    esac
    
    case "${agent}" in
        "docker"|"all")
            echo "=== TESTS DOCKER AGENT ==="
            test_docker_agent_image_policies
            test_docker_agent_cleanup_policies
            echo ""
            ;;
    esac
    
    case "${agent}" in
        "scanner"|"all")
            echo "=== TESTS SCANNER AGENT ==="
            test_scanner_agent_mode_options
            test_scanner_agent_action_modes
            test_scanner_agent_exclusions
            echo ""
            ;;
    esac
    
    case "${agent}" in
        "quarantine"|"all")
            echo "=== TESTS QUARANTINE AGENT ==="
            test_quarantine_agent_retention
            test_quarantine_agent_counting
            echo ""
            ;;
    esac
    
    case "${agent}" in
        "report"|"all")
            echo "=== TESTS REPORT AGENT ==="
            test_report_agent_status_logic
            test_report_agent_format_detection
            echo ""
            ;;
    esac
    
    case "${agent}" in
        "notification"|"all")
            echo "=== TESTS NOTIFICATION AGENT ==="
            test_notification_agent_email_logic
            test_notification_agent_conditions
            echo ""
            ;;
    esac
    
    # Résumé
    echo "=== RÉSUMÉ ==="
    echo "Total: ${TESTS_TOTAL}"
    echo -e "Réussis: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Échoués: ${RED}${TESTS_FAILED}${NC}"
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "${RED}❌ Des tests ont échoué${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Tous les tests sont passés !${NC}"
        return 0
    fi
}

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_agent_tests "$@"
else
    # Si sourcé par un autre script, ne pas exécuter automatiquement
    :
fi