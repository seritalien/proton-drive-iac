# Architecture

## Vue d'ensemble

Ce projet propose deux implémentations pour intégrer Proton Drive à une
machine Linux, activées selon ce qui fonctionne réellement au moment de
l'installation. Les deux partagent la même infrastructure de sécurité et
de surveillance.

```
┌─────────────────────────────┐        ┌─────────────────────────────┐
│   CHEMIN CIBLE (rclone)      │        │   CHEMIN DE REPLI (CLI)      │
│                              │        │                              │
│  ~/ProtonDrive (mount FUSE)  │        │  ~/ProtonDrive (dossier)     │
│         │                    │        │         │◄───── pull ───────┤
│         ▼                    │        │         ├────── push ──────►│
│  rclone mount protondrive:   │        │  sync périodique (CLI off.) │
│         │                    │        │         │                   │
│  proton-drive-mount.service  │        │  proton-drive-cli-sync.timer│
│  proton-drive-healthcheck    │        │                              │
└─────────────┬────────────────┘        └─────────────┬────────────────┘
              │                                        │
              └────────────────┬───────────────────────┘
                                ▼
              proton-drive-failure-notify.service
                  (alerte desktop, commune aux deux)
```

## Chemin cible : montage FUSE natif

```
~/ProtonDrive  (mount FUSE, cache VFS local)
      │
      ▼
rclone mount protondrive:  ──password-command──►  fichier local (permissions restrictives)
      │
      ├── proton-drive-mount.service        (montage, redémarre seul en cas de coupure)
      ├── proton-drive-failure-notify.service  (alerte desktop au moindre échec)
      └── proton-drive-healthcheck.timer    (contrôle périodique : montage
                                              vivant, cache pas saturé, pas
                                              d'erreurs qui s'accumulent)
```

Un montage FUSE donne un accès transparent : n'importe quelle application
(gestionnaire de fichiers, éditeur, terminal) traite `~/ProtonDrive` comme
un dossier normal, sans commande spéciale.

**Pourquoi pas de chiffrement additionnel (`rclone crypt`) par-dessus** :
Proton Drive fait déjà du chiffrement de bout en bout côté serveur. Ajouter
une couche `crypt` transformerait les fichiers en blocs opaques
illisibles par les applications officielles (mobile, web) — ce qui casse
l'objectif d'un accès natif multi-appareils. Ce choix est adapté à un
usage "drive personnel visible partout" ; un usage purement "sauvegarde
chiffrée jamais consultée ailleurs" justifierait un choix différent.

## Chemin de repli : synchronisation via le CLI officiel

```
~/ProtonDrive (dossier local classique)
      │  pull (download, résolution de conflit par nom)
      ▼◄────────────────────────────────┐
   script de synchronisation            │
      │  push (upload, résolution de conflit par nom)
      ▼────────────────────────────────►┘
Proton Drive (cloud)
      │
proton-drive-cli-sync.timer (planifié, verrouillage anti-chevauchement)
      └── alerte desktop au moindre échec
```

Ce chemin s'appuie sur le CLI officiel Proton (`filesystem
upload`/`download`), qui n'a pas de mount natif : c'est une synchronisation
périodique, pas un accès transparent en continu.

**Limite structurelle honnête** : ce CLI n'a pas de véritable moteur de
synchronisation (pas de comparaison par date de modification/contenu) —
seulement une résolution de conflit par nom de fichier (ignorer, fusionner,
remplacer, garder les deux). Un fichier modifié des deux côtés sous le
même nom n'est pas fusionné intelligemment : la stratégie retenue
détermine simplement lequel des deux exemplaires est conservé. Ce mode
convient pour faire remonter/redescendre des ajouts, pas pour un usage
type "édition simultanée multi-appareils".

**Concurrence** : le cache local de ce CLI n'est pas conçu pour des accès
simultanés — deux invocations en parallèle provoquent une erreur de
verrouillage de base de données. Toute automatisation autour de ce CLI
doit sérialiser ses appels (verrou de fichier applicatif), et regrouper
plusieurs chemins dans un seul appel plutôt que multiplier les processus
(chaque invocation a un coût de démarrage fixe, réouverture de cache
compris).

## Gestion des secrets

Deux catégories de secrets entrent en jeu, traitées différemment :

1. **Identifiants du compte** (chemin CLI officiel) : gérés directement
   par l'outil officiel via le trousseau de sécurité du système
   d'exploitation quand disponible (ex. service de gestion de secrets
   standard sous Linux) — rien à construire côté projet.

2. **Mot de passe de chiffrement de configuration** (chemin rclone) :
   secret technique généré aléatoirement, nécessaire pour que le montage
   fonctionne sans interaction au démarrage. Approche retenue : fichier à
   permissions restrictives (lecture seule par le propriétaire),
   cohérente avec un service utilisateur classique, sans privilège
   administrateur requis.

   Une approche plus robuste existe (secret scellé et lié
   matériellement à la machine, déchiffré uniquement par le
   gestionnaire système), mais elle nécessite un module de sécurité
   matériel absent de toutes les machines et une intervention
   administrateur ponctuelle — hors scope d'une installation
   automatisée simple. Le projet documente ce chemin de montée en
   robustesse pour qui en a besoin.

Dans tous les cas : **aucun identifiant de compte réel** (email, mot de
passe, code de double authentification) ne transite jamais par un script
automatisé — l'authentification initiale est toujours une étape manuelle,
effectuée par l'utilisateur dans son propre terminal.

## Fiabilité : pourquoi l'alerte n'est pas optionnelle

Une tâche planifiée sans surveillance qui échoue silencieusement peut
rester cassée pendant des semaines sans que personne ne s'en aperçoive —
c'est un piège classique des automatisations "installer et oublier". Ce
projet traite la notification d'échec comme faisant partie du socle, pas
comme une amélioration optionnelle : toute unité systemd du projet
déclenche une alerte desktop visible dès le premier échec, et un contrôle
de santé périodique vérifie activement que tout répond correctement
plutôt que d'attendre un rapport d'erreur.

## Reproductibilité

Chaque étape d'installation est idempotente (relançable sans effet de
bord) et ne dépend d'aucune donnée spécifique à une machine ou un compte
préexistants : les secrets sont générés localement au premier lancement,
et l'authentification est toujours refaite explicitement sur chaque
nouvelle installation. Le projet peut être cloné et redéployé à
l'identique sur plusieurs machines sans partage d'état entre elles.

## Limites connues (état au moment de la rédaction)

- Le backend de montage natif dépend d'un composant tiers dont la
  compatibilité avec l'API Proton peut évoluer indépendamment de ce
  projet — un échec de connexion à ce niveau n'indique pas nécessairement
  un problème de configuration locale.
- Le chemin de repli n'offre pas de vraie détection de modification
  concurrente (voir plus haut) — à réserver à un usage de synchronisation
  d'ajouts, pas d'édition collaborative.
- Il n'existe pas, côté fournisseur, d'équivalent d'un jeton d'accès à
  portée restreinte (type clé de service cloud classique) : toute
  automatisation non interactive nécessite les identifiants complets du
  compte.
