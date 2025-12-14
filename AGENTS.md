# AGENTS - Architecture du Projet ClamAV Scanner

## 🏗️ Vue d'ensemble du système

Ce document décrit l'architecture basée sur des agents pour le système de scan antivirus ClamAV dockerisé.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ÉCOSYSTÈME CLAMAV SCANNER                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐ │
│  │   AGENT     │───►│   AGENT     │───►│      AGENT DOCKER       │ │
│  │CONFIG/CHECK │    │ SIGNATURES  │    │   (Container Manager)   │ │
│  └─────────────┘    └─────────────┘    └───────────┬─────────────┘ │
│                                                     │               │
│                                                     ▼               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐ │
│  │   AGENT     │◄───│    AGENT    │◄───│     AGENT SCANNER       │ │
│  │ NOTIFICATION│    │ QUARANTINE  │    │     (ClamAV Engine)     │ │
│  └─────────────┘    └─────────────┘    └─────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🤖 Agents Identifiés

### 1. Agent Configuration & Prérequis (`ConfigAgent`)

**Responsabilités:**
- Validation des prérequis système (Docker, permissions)
- Création/vérification des répertoires de travail
- Gestion des variables d'environnement
- Parsing et validation des arguments CLI

**Entrées:**
- Arguments de ligne de commande
- Variables d'environnement
- Configuration système

**Sorties:**
- Configuration validée
- Répertoires initialisés
- Status de validation

**Code associé:**
```bash
check_prerequisites()
parse_arguments()
```

---

### 2. Agent Signatures (`SignatureAgent`)

**Responsabilités:**
- Mise à jour des signatures antivirus (freshclam)
- Gestion du cache des définitions
- Validation de l'intégrité des signatures
- Planification des mises à jour

**Entrées:**
- Répertoire des signatures existantes
- Configuration de mise à jour

**Sorties:**
- Signatures mises à jour
- Rapport de mise à jour
- Status de validation

**Code associé:**
```bash
update_signatures()
```

**Données gérées:**
```
/var/lib/clamav/
├── main.cvd      # Base principale
├── daily.cvd     # MAJ quotidiennes  
└── bytecode.cvd  # Détection avancée
```

---

### 3. Agent Docker (`DockerAgent`)

**Responsabilités:**
- Gestion du cycle de vie des containers
- Pull/management des images Docker
- Configuration des volumes et networks
- Nettoyage des containers orphelins

**Entrées:**
- Configuration container
- Volumes à monter
- Image Docker à utiliser

**Sorties:**
- Container opérationnel
- Volumes montés
- Status d'exécution

**Code associé:**
```bash
pull_docker_image()
stop_existing_container()
# Container lifecycle dans run_scan()
```

**Actions:**
- `docker pull clamav/clamav:latest`
- `docker run --rm` avec bind mounts
- Cleanup automatique

---

### 4. Agent Scanner (`ScannerAgent`)

**Responsabilités:**
- Orchestration du scan antivirus
- Configuration des options de scan (standard/complet)
- Monitoring de l'progression
- Gestion des timeouts et erreurs

**Entrées:**
- Répertoire à scanner
- Options de scan (complet/standard)
- Exclusions et limites

**Sorties:**
- Résultats de scan
- Fichiers infectés détectés
- Logs d'activité
- Code de retour

**Code associé:**
```bash
run_scan()
```

**Modes de fonctionnement:**
```
┌─────────────────┬─────────────────────┬─────────────────────┐
│                 │     STANDARD        │      COMPLET        │
├─────────────────┼─────────────────────┼─────────────────────┤
│ Vitesse         │ ⚡ Rapide           │ 🐌 Lent             │
├─────────────────┼─────────────────────┼─────────────────────┤
│ Profondeur      │ Fichiers basiques   │ Archives, mails,    │
│                 │                     │ PDF, HTML           │
├─────────────────┼─────────────────────┼─────────────────────┤
│ Usage           │ Scans quotidiens    │ Scans hebdo/audit   │
└─────────────────┴─────────────────────┴─────────────────────┘
```

---

### 5. Agent Quarantaine (`QuarantineAgent`)

**Responsabilités:**
- Gestion des fichiers infectés
- Actions: quarantaine, suppression, copie
- Nettoyage automatique ancien contenu
- Gestion des permissions de sécurité

**Entrées:**
- Fichiers infectés détectés
- Mode d'action configuré (quarantine/remove)

**Sorties:**
- Fichiers traités selon configuration
- Logs des actions effectuées
- Inventaire de la quarantaine

**Modes d'action:**
```
┌─────────────────┬─────────────────────┬─────────────────────┐
│                 │    QUARANTAINE      │      SUPPRESSION    │
│                 │     (--move)        │       (--remove)    │
├─────────────────┼─────────────────────┼─────────────────────┤
│ Récupération    │ ✅ Possible         │ ❌ Impossible       │
├─────────────────┼─────────────────────┼─────────────────────┤
│ Espace disque   │ ⚠️ Utilisé          │ ✅ Libéré          │
├─────────────────┼─────────────────────┼─────────────────────┤
│ Sécurité        │ ⚠️ Fichier existe   │ ✅ Détruit         │
└─────────────────┴─────────────────────┴─────────────────────┘
```

---

### 6. Agent Rapport (`ReportAgent`)

**Responsabilités:**
- Génération de rapports structurés
- Calcul des métriques et statistiques
- Formatage des résultats (texte, JSON)
- Archivage des historiques

**Entrées:**
- Résultats du scan
- Logs d'activité
- Métriques de performance

**Sorties:**
- Rapport formaté
- Résumé exécutif
- Métriques exportables

**Code associé:**
```bash
generate_report()
```

**Format du rapport:**
```
================================================================================
                      RAPPORT D'ANALYSE ANTIVIRUS CLAMAV
================================================================================

${status_icon} STATUT: ${status}

📅 Date d'analyse     : $(date)
📂 Répertoire scanné  : ${SCAN_DIR}
⏱️  Durée de l'analyse : ${duration} secondes
🦠 Fichiers infectés  : ${quarantine_count}
📦 Quarantaine        : ${QUARANTINE_DIR}
```

---

### 7. Agent Notification (`NotificationAgent`)

**Responsabilités:**
- Envoi de notifications email
- Intégrations futures (Slack, Discord, webhooks)
- Gestion des templates de messages
- Routage selon la criticité

**Entrées:**
- Résultats de scan
- Configuration notifications
- Templates de messages

**Sorties:**
- Notifications envoyées
- Logs de livraison
- Status d'envoi

**Code associé:**
```bash
send_email_notification()
```

**Extensions futures:**
- 📱 Slack/Discord webhooks
- 📊 Intégration monitoring (Grafana)
- 🔔 Notifications push mobiles

---

## 🔄 Flux d'exécution inter-agents

```
START
  │
  ▼
┌─────────────┐
│ ConfigAgent │ ──► Validation système
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ SignatureAgent  │ ──► MAJ définitions virus
└──────┬──────────┘
       │
       ▼
┌─────────────┐
│ DockerAgent │ ──► Préparation container
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ ScannerAgent    │ ──► Analyse antivirus
└──────┬──────────┘
       │
       ▼
┌──────────────────┐
│ QuarantineAgent  │ ──► Traitement fichiers infectés
└──────┬───────────┘
       │
       ▼
┌─────────────────┐    ┌──────────────────┐
│ ReportAgent     │───►│ NotificationAgent│
└─────────────────┘    └──────────────────┘
       │                        │
       ▼                        ▼
   Rapport                 Email/Alerts
```

---

## 📊 Interface entre agents

### Messages/Données échangées

```python
# Structure de données partagée (concept)
class ScanContext:
    config: ConfigData
    scan_results: ScanResults
    quarantine_status: QuarantineStatus
    metrics: PerformanceMetrics
    
class ScanResults:
    exit_code: int
    infected_files: List[str]
    duration: int
    files_scanned: int
    errors: List[str]
```

### Points de synchronisation

| Agent A | Agent B | Interface | Données |
|---------|---------|-----------|---------|
| Config | Signature | FileSystem | `/var/lib/clamav/` |
| Signature | Docker | Volume | Signatures mount |
| Docker | Scanner | Container | ClamAV runtime |
| Scanner | Quarantine | FileSystem | Infected files list |
| Quarantine | Report | Status | Action results |
| Report | Notification | Message | Formatted report |

---

## 🛠️ Extensions futures

### Agent Scheduler (`SchedulerAgent`)
- Planification automatique des scans
- Gestion des fenêtres de maintenance
- Optimisation des ressources

### Agent Monitoring (`MonitoringAgent`)  
- Métriques temps réel
- Alertes sur performances
- Intégration Prometheus/Grafana

### Agent API (`APIAgent`)
- Interface REST pour déclenchement distant
- Statuts en temps réel
- Intégration CI/CD

### Agent Database (`DatabaseAgent`)
- Historique des scans
- Trending des menaces
- Analytics avancées

---

## 🔧 Configuration des agents

### Gestion des variables d'environnement

Le projet utilise une approche en couches pour la configuration :

```
┌─────────────────────────────────────────────────────────────────┐
│                    HIÉRARCHIE DE CONFIGURATION                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   .env.example  ──► .env  ──► .env.local  ──► Variables CLI     │
│   (template)       (base)   (surcharge)     (priorité max)     │
│                                                                 │
│   ✅ Versionné    ❌ Ignoré  ❌ Ignoré      🔄 Runtime          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Structure des fichiers de configuration

**`.env.example`** (template versionné)
```bash
# =============================================================================
# CONFIGURATION CLAMAV SCANNER - TEMPLATE
# =============================================================================
# Copier ce fichier vers .env et adapter selon vos besoins

# CONFIGURATION GÉNÉRALE
SCAN_DIR=/data
QUARANTINE_DIR=/var/clamav/quarantine
LOG_DIR=/var/log/clamav
SIGNATURES_DIR=/var/lib/clamav

# AGENTS CONFIGURATION
CONFIG_AGENT_LOG_LEVEL=INFO
SIGNATURE_AGENT_UPDATE_FREQUENCY=daily
DOCKER_AGENT_CLEANUP_POLICY=auto
SCANNER_AGENT_DEFAULT_MODE=standard
QUARANTINE_AGENT_ACTION=quarantine
QUARANTINE_AGENT_RETENTION_DAYS=7
REPORT_AGENT_FORMAT=text

# NOTIFICATIONS
NOTIFICATION_AGENT_ENABLED=false
EMAIL_ENABLED=false
EMAIL_TO=admin@example.com
EMAIL_FROM=clamav-scanner@localhost

# DOCKER
DOCKER_IMAGE=clamav/clamav:latest
CONTAINER_NAME=clamav-scanner

# LIMITES DE SCAN
MAX_FILE_SIZE=100M
MAX_SCAN_SIZE=500M

# EXCLUSIONS (patterns séparés par |)
EXCLUDE_DIRS="^/proc|^/sys|^/dev"
EXCLUDE_FILES="*.tmp|*.log"
```

**`.env`** (configuration locale - non versionné)
```bash
# Configuration locale - ne pas commiter ce fichier
SCAN_DIR=/home/user/data
EMAIL_TO=david@mondomaine.com
NOTIFICATION_AGENT_ENABLED=true
```

### Variables par agent

| Agent | Variables | Description |
|-------|-----------|-------------|
| **ConfigAgent** | `CONFIG_AGENT_LOG_LEVEL` | Niveau de log (DEBUG,INFO,WARN,ERROR) |
| **SignatureAgent** | `SIGNATURE_AGENT_UPDATE_FREQUENCY` | Fréquence MAJ (daily,weekly,manual) |
| **DockerAgent** | `DOCKER_AGENT_CLEANUP_POLICY`<br/>`DOCKER_IMAGE`<br/>`CONTAINER_NAME` | Nettoyage auto<br/>Image Docker<br/>Nom container |
| **ScannerAgent** | `SCANNER_AGENT_DEFAULT_MODE`<br/>`MAX_FILE_SIZE`<br/>`MAX_SCAN_SIZE` | Mode par défaut<br/>Limite taille fichier<br/>Limite scan total |
| **QuarantineAgent** | `QUARANTINE_AGENT_ACTION`<br/>`QUARANTINE_AGENT_RETENTION_DAYS` | Action (quarantine/remove)<br/>Rétention en jours |
| **ReportAgent** | `REPORT_AGENT_FORMAT` | Format rapport (text/json/html) |
| **NotificationAgent** | `NOTIFICATION_AGENT_ENABLED`<br/>`EMAIL_ENABLED`<br/>`EMAIL_TO`<br/>`EMAIL_FROM` | Activation notifications<br/>Email activé<br/>Destinataire<br/>Expéditeur |

---

## 📁 Structure du projet

```
clamav-scan/
├── .env.example              # Template de configuration (versionné)
├── .env                      # Configuration locale (ignoré par git)
├── .env.local               # Surcharge locale optionnelle (ignoré par git)
├── .gitignore               # Exclut .env et .env.local
├── clamav-scan.sh           # Script principal
├── AGENTS.md                # Architecture (ce document)
├── README.md                # Documentation utilisateur
└── dev/                     # Développement
    ├── conversation.md      # Notes de conception
    └── tests/               # Scripts de test
```

### .gitignore recommandé

```gitignore
# Configuration locale
.env
.env.local

# Logs
*.log
logs/

# Données temporaires
/quarantine/*
/signatures/*

# IDE
.vscode/
.idea/

# Système
.DS_Store
Thumbs.db
```

---

Cette architecture modulaire permet:
- ✅ **Séparation des responsabilités**
- ✅ **Facilité de maintenance**
- ✅ **Extensions futures**
- ✅ **Testing isolé**
- ✅ **Monitoring granulaire**
- ✅ **Configuration flexible et sécurisée**