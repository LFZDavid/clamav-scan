# Tests - ClamAV Docker Scanner

Ce répertoire contient une suite complète de tests automatisés pour valider toutes les fonctionnalités du scanner ClamAV.

## 🧪 Structure des tests

```
dev/tests/
├── run-all-tests.sh        # 🚀 Lanceur principal
├── test-suite.sh          # 🔧 Tests d'intégration complets  
├── test-agents.sh         # ⚡ Tests unitaires des agents
├── test-performance.sh    # 📊 Tests de performance
└── README.md             # Cette documentation
```

## 🚀 Exécution rapide

### Tous les tests
```bash
./dev/tests/run-all-tests.sh
```

### Tests rapides (sans Docker)
```bash
./dev/tests/run-all-tests.sh --quick
```

### Tests spécifiques
```bash
./dev/tests/run-all-tests.sh --agents       # Tests unitaires
./dev/tests/run-all-tests.sh --performance  # Tests de performance
```

## 📋 Types de tests détaillés

### 1. Tests unitaires des agents (`test-agents.sh`)

**Objectif :** Valider la logique de chaque agent individuellement

**Tests couverts :**
- ✅ **ConfigAgent** - Validation Docker, permissions, création répertoires
- ✅ **SignatureAgent** - Logique de fréquence, mode manuel
- ✅ **DockerAgent** - Politiques de pull et cleanup
- ✅ **ScannerAgent** - Modes de scan, actions, exclusions
- ✅ **QuarantineAgent** - Rétention, comptage des fichiers
- ✅ **ReportAgent** - Statuts, formats de sortie
- ✅ **NotificationAgent** - Logique email, conditions d'envoi

**Exécution :**
```bash
# Tous les agents
./dev/tests/test-agents.sh

# Agent spécifique
./dev/tests/test-agents.sh config
./dev/tests/test-agents.sh scanner
```

### 2. Tests d'intégration (`test-suite.sh`)

**Objectif :** Valider le fonctionnement complet avec Docker

**Tests couverts :**
- 🔧 **Syntaxe et CLI** - Validation bash, options, aide
- ⚙️ **Configuration** - Chargement .env, validation répertoires  
- 🐳 **Intégration Docker** - Mise à jour signatures, scans réels
- 🦠 **Détection** - Test avec fichier EICAR
- 📦 **Quarantaine** - Modes quarantine/remove/copy
- 📊 **Rapports** - Génération text/JSON
- 🔍 **Modes de scan** - quick/standard/full
- ⚠️ **Gestion d'erreurs** - Docker absent, permissions

**Exécution :**
```bash
# Tests complets
./dev/tests/test-suite.sh --integration

# Tests rapides (sans Docker intensif)
./dev/tests/test-suite.sh --quick

# Mise à jour signatures seulement
./dev/tests/test-suite.sh --update-only
```

### 3. Tests de performance (`test-performance.sh`)

**Objectif :** Mesurer les performances et détecter les régressions

**Tests couverts :**
- ⚡ **Scan rapide** - Dataset petit (seuil: 30s)
- 🔄 **Scan standard** - Dataset moyen (seuil: 120s)
- 🐌 **Scan complet** - Dataset moyen (seuil: 300s)
- 📈 **Large dataset** - 1000 fichiers
- 💾 **Utilisation mémoire** - Moins de 500MB
- 🔄 **Scans concurrents** - Plusieurs containers
- 🔥 **Stress tests** - Limites et exclusions

**Seuils de performance :**
```bash
QUICK_SCAN_THRESHOLD=30      # 30 secondes max
STANDARD_SCAN_THRESHOLD=120  # 2 minutes max  
FULL_SCAN_THRESHOLD=300     # 5 minutes max
```

**Exécution :**
```bash
./dev/tests/test-performance.sh
```

## 📊 Données de test

### Datasets générés automatiquement

| Dataset | Taille | Fichiers | Usage |
|---------|--------|----------|--------|
| **Small** | ~1MB | 10 fichiers | Tests rapides |
| **Medium** | ~10MB | 100 fichiers | Tests standard |
| **Large** | ~100MB | 1000 fichiers | Tests performance |

### Fichiers spéciaux

- **EICAR** - Fichier de test antivirus standard
- **Scripts** - `.sh`, `.html`, `.json` pour tests de types
- **Archives** - Pour tests de scan complet

## 🛠️ Outils requis

### Prérequis système
```bash
# Docker (obligatoire)
docker --version

# bc (pour tests de performance)
sudo apt install bc

# Outils standard
bash, find, mkdir, rm, chmod
```

### Variables d'environnement de test
```bash
# Les tests utilisent leurs propres configurations
TEST_DATA_DIR="/tmp/clamav-test-$$"
TEST_CONFIG_DIR="/tmp/clamav-config-$$"

# Pas d'impact sur votre configuration locale
```

## 🚀 Intégration CI/CD

### GitHub Actions exemple
```yaml
name: Tests ClamAV Scanner
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: sudo apt update && sudo apt install -y bc
      - name: Run tests
        run: ./dev/tests/run-all-tests.sh --quick
```

### Script de pre-commit
```bash
#!/bin/bash
# .git/hooks/pre-commit
./dev/tests/run-all-tests.sh --quick
```

## 📈 Exemples d'utilisation

### Tests avant commit
```bash
# Tests rapides (2-5 minutes)
./dev/tests/run-all-tests.sh --quick

# Tests complets (10-15 minutes)  
./dev/tests/run-all-tests.sh
```

### Tests de régression
```bash
# Après modification du code
./dev/tests/test-agents.sh

# Après modification de configuration
./dev/tests/test-suite.sh --quick
```

### Tests de performance
```bash
# Benchmark complet
./dev/tests/test-performance.sh

# Vérifier les seuils uniquement
./dev/tests/test-performance.sh 2>/dev/null | grep -E "(PASS|FAIL)"
```

### Debugging des tests
```bash
# Mode verbeux
./dev/tests/run-all-tests.sh --verbose

# Test d'un agent spécifique  
./dev/tests/test-agents.sh scanner

# Nettoyer l'environnement de test
./dev/tests/run-all-tests.sh --cleanup
```

## 📊 Interprétation des résultats

### Codes de retour
- `0` - ✅ Tous les tests sont passés
- `1` - ❌ Au moins un test a échoué

### Format des résultats
```
🧪 SUITE COMPLÈTE DE TESTS CLAMAV 🧪

╔══════════════════════════════════════╗
║              RAPPORT FINAL           ║
╠══════════════════════════════════════╣
║  Suites de tests  : 3                ║
║  Suites réussies  : 3                ║  
║  Suites échouées  : 0                ║
║  Taux de réussite : 100%             ║
╚══════════════════════════════════════╝

🎉 Toutes les suites de tests sont passées !
```

## 🔧 Maintenance des tests

### Ajouter un nouveau test
```bash
# Dans test-agents.sh
test_new_agent_feature() {
    ((TESTS_TOTAL++))
    log_test "Test de la nouvelle fonctionnalité..."
    
    if condition_test; then
        log_success "Test réussi"
    else  
        log_failure "Test échoué"
    fi
}
```

### Mise à jour des seuils de performance
```bash
# Dans test-performance.sh
readonly QUICK_SCAN_THRESHOLD=30    # Ajuster selon besoin
readonly STANDARD_SCAN_THRESHOLD=120
readonly FULL_SCAN_THRESHOLD=300
```

## 📞 Support

En cas de problème avec les tests :

1. **Vérifier les prérequis** - Docker, bc, permissions
2. **Nettoyer l'environnement** - `./run-all-tests.sh --cleanup`
3. **Mode verbeux** - `./run-all-tests.sh --verbose`
4. **Tests isolés** - Exécuter une suite spécifique

---

**Les tests garantissent la qualité et la fiabilité du scanner ClamAV ! 🛡️**