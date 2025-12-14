# Guide de contribution - ClamAV Docker Scanner

## 🤝 Bienvenue contributeurs !

Merci de votre intérêt pour contribuer au projet ClamAV Docker Scanner ! Ce guide vous explique comment participer au développement.

## 🎯 Types de contributions

- 🐛 **Correction de bugs**
- ✨ **Nouvelles fonctionnalités** 
- 📚 **Amélioration de la documentation**
- 🧪 **Tests et validation**
- 🔧 **Optimisations de performance**
- 🌐 **Traductions**

## 📋 Avant de commencer

### Prérequis

- **Git** configuré avec votre identité
- **Docker** installé et fonctionnel
- **Bash** 4.0+ pour les tests
- **Éditeur** avec support Markdown

### Environnement de développement

```bash
# Fork et clone du projet
git clone https://github.com/VOTRE-USERNAME/clamav-scan.git
cd clamav-scan

# Configuration Git
git config user.name "Votre Nom"
git config user.email "votre.email@example.com"

# Branche de développement
git checkout -b feature/votre-fonctionnalite
```

## 🏗️ Architecture du projet

### Structure des fichiers

```
clamav-scan/
├── clamav-scan.sh           # Script principal (agents)
├── .env.example             # Template de configuration
├── README.md                # Documentation principale
├── AGENTS.md                # Architecture détaillée
├── docs/                    # Documentation avancée
│   ├── CONFIGURATION.md     # Guide de configuration
│   ├── TROUBLESHOOTING.md   # Résolution de problèmes
│   └── CONTRIBUTING.md      # Ce fichier
└── dev/                     # Développement et tests
    ├── conversation.md      # Notes de conception
    └── tests/               # Scripts de test
```

### Architecture des agents

Le projet utilise une architecture modulaire basée sur 7 agents :

1. **ConfigAgent** - Validation et configuration
2. **SignatureAgent** - Mise à jour des signatures
3. **DockerAgent** - Gestion des containers
4. **ScannerAgent** - Orchestration du scan
5. **QuarantineAgent** - Traitement des fichiers infectés
6. **ReportAgent** - Génération des rapports
7. **NotificationAgent** - Envoi d'alertes

**📖 Voir [AGENTS.md](../AGENTS.md) pour l'architecture complète**

## 🔧 Standards de développement

### Conventions de code Bash

```bash
# Variables en MAJUSCULES avec fallback
readonly SCAN_DIR="${SCAN_DIR:-/data}"

# Fonctions avec préfixe agent
config_agent_validate() {
    local message="$1"
    # ...
}

# Gestion d'erreurs systématique
if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé"
    exit 1
fi

# Logs avec niveaux
log_info "[AgentName] Message informatif"
log_error "[AgentName] Message d'erreur"
```

### Conventions de nommage

- **Fonctions** : `agent_name_action()` (snake_case)
- **Variables globales** : `UPPER_CASE`
- **Variables locales** : `lower_case`
- **Constants** : `readonly CONSTANT_NAME`

### Documentation du code

```bash
#-------------------------------------------------------------------------------
# AGENT NAME - Description de l'agent
#-------------------------------------------------------------------------------

# Description de la fonction
# Paramètres:
#   $1 - Description du paramètre
# Retourne:
#   0 - Succès
#   1 - Erreur
function_name() {
    local param="$1"
    # Code...
}
```

## ✅ Tests et validation

### Tests avant commit

```bash
# Script de test complet
cat > dev/test-all.sh << 'EOF'
#!/bin/bash
set -e

echo "🧪 Tests ClamAV Scanner"
echo "======================="

# Test de syntaxe bash
echo "1. Test syntaxe..."
bash -n clamav-scan.sh
echo "✅ Syntaxe OK"

# Test avec ShellCheck si disponible
if command -v shellcheck &> /dev/null; then
    echo "2. Test ShellCheck..."
    shellcheck clamav-scan.sh
    echo "✅ ShellCheck OK"
fi

# Test de configuration
echo "3. Test configuration..."
source .env.example
echo "✅ Configuration OK"

# Test avec répertoire vide
echo "4. Test scan répertoire vide..."
mkdir -p /tmp/test-clamav-empty
SCAN_DIR=/tmp/test-clamav-empty \
QUARANTINE_DIR=/tmp/test-quarantine \
LOG_DIR=/tmp/test-logs \
SIGNATURES_DIR=/tmp/test-signatures \
./clamav-scan.sh --update-only
echo "✅ Test scan OK"

echo "🎉 Tous les tests passés !"
EOF

chmod +x dev/test-all.sh
./dev/test-all.sh
```

### Test avec fichier de test EICAR

```bash
# Créer un fichier de test virus (EICAR)
mkdir -p /tmp/test-malware
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/test-malware/eicar.txt

# Tester la détection
./clamav-scan.sh -d /tmp/test-malware -v

# Nettoyer
rm -rf /tmp/test-malware
```

### Tests de régression

```bash
# Tester tous les modes
./clamav-scan.sh -d /tmp --quick
./clamav-scan.sh -d /tmp --full
./clamav-scan.sh -d /tmp  # standard

# Tester toutes les actions
ACTION_MODE=quarantine ./clamav-scan.sh -d /tmp
ACTION_MODE=remove ./clamav-scan.sh -d /tmp
ACTION_MODE=copy ./clamav-scan.sh -d /tmp
```

## 📝 Guidelines pour les Pull Requests

### Structure d'une PR

1. **Titre clair** : `[Type] Description courte`
   - Types : `feat`, `fix`, `docs`, `refactor`, `test`
   
2. **Description détaillée** :
   ```
   ## 🎯 Objectif
   Description de ce que fait la PR
   
   ## 🔧 Changements
   - Liste des modifications
   - Impact sur l'existant
   
   ## 🧪 Tests
   - Tests effectués
   - Cas de test couverts
   
   ## 📋 Checklist
   - [ ] Tests passés
   - [ ] Documentation mise à jour
   - [ ] Backward compatible
   ```

### Processus de review

1. **Auto-review** avant soumission
2. **Tests automatiques** (si CI/CD configuré)
3. **Review par les mainteneurs**
4. **Corrections** si nécessaire
5. **Merge** après validation

### Commit messages

Format : `type(scope): description`

```bash
# Exemples
feat(scanner): add quick scan mode
fix(docker): resolve container cleanup issue
docs(readme): update installation instructions
refactor(agents): improve error handling
```

## 🆕 Développement de nouvelles fonctionnalités

### Ajouter un nouvel agent

```bash
#-------------------------------------------------------------------------------
# NOUVEL AGENT - Description
#-------------------------------------------------------------------------------

nouvel_agent_fonction() {
    log_info "[NouvelAgent] Description de l'action..."
    
    # Logique de l'agent
    
    log_success "[NouvelAgent] Action terminée"
}
```

### Ajouter de nouvelles options CLI

```bash
# Dans parse_arguments()
case $1 in
    --nouvelle-option)
        NOUVELLE_VARIABLE="$2"
        shift 2
        ;;
    # ...
esac

# Dans show_help()
echo "    --nouvelle-option      Description de l'option"
```

### Ajouter de nouvelles variables de configuration

```bash
# Dans .env.example
# NOUVEAU PARAMETRE
NOUVEAU_PARAMETRE=valeur_defaut           # Description

# Dans le script
readonly NOUVEAU_PARAM="${NOUVEAU_PARAMETRE:-defaut}"
```

## 🐛 Correction de bugs

### Workflow de correction

1. **Reproduire** le bug localement
2. **Identifier** la cause racine
3. **Corriger** avec la solution minimale
4. **Tester** la correction
5. **Vérifier** la non-régression

### Debug et logs

```bash
# Activer le debug complet
DEBUG_MODE=true
VERBOSE_DOCKER=true
CONFIG_AGENT_VERBOSE=true
./clamav-scan.sh -v

# Analyser les logs
tail -f /var/log/clamav/scan_*.log
```

## 📚 Documentation

### Mise à jour de la documentation

- **README.md** : Vue d'ensemble et usage de base
- **docs/CONFIGURATION.md** : Configuration détaillée
- **docs/TROUBLESHOOTING.md** : Résolution de problèmes
- **AGENTS.md** : Architecture technique

### Standards de documentation

- **Markdown** standard avec extensions GitHub
- **Emojis** pour améliorer la lisibilité
- **Exemples concrets** avec code
- **Captures d'écran** si nécessaire

## 🔄 Processus de release

### Versioning

Le projet suit le [Semantic Versioning](https://semver.org/) :

- **MAJOR** : Changements incompatibles
- **MINOR** : Nouvelles fonctionnalités compatibles
- **PATCH** : Corrections de bugs

### Checklist de release

```bash
# Avant la release
- [ ] Tous les tests passent
- [ ] Documentation à jour
- [ ] CHANGELOG.md mis à jour
- [ ] Version bumped dans le script
- [ ] Tag Git créé

# Process de release
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin v2.1.0
```

## 🎖️ Reconnaissance des contributeurs

Les contributeurs sont listés dans :
- **README.md** (section contributors)
- **CONTRIBUTORS.md** (fichier dédié si nécessaire)
- **Release notes** pour les contributions importantes

## 📞 Contact et support

- **Issues GitHub** : Questions techniques et bugs
- **Discussions** : Idées et suggestions générales
- **Email** : Pour les questions privées

## 📄 Licence

En contribuant, vous acceptez que vos contributions soient sous la même licence que le projet (MIT).

---

**Merci de contribuer à améliorer la sécurité des serveurs ! 🛡️**