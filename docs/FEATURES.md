# Fonctionnalités

## Objectif

Intégrer Proton Drive à une machine Linux comme un espace de stockage
utilisable au quotidien — sans dépendre d'un outil non maintenu, sans
secret en clair sur disque, et sans surveillance manuelle constante.

## Deux chemins d'intégration

Le projet supporte deux approches, choisies automatiquement selon ce qui
fonctionne réellement au moment de l'installation :

### 1. Montage natif (cible)

Un point de montage FUSE (`~/ProtonDrive`) qui se comporte comme un
dossier local classique — lecture/écriture directe, visible dans
n'importe quel gestionnaire de fichiers, sans commande spéciale.

- Basé sur [rclone](https://rclone.org) (backend `protondrive`)
- Cache VFS local pour des performances proches du disque natif
- Démarre automatiquement au login, redémarre seul en cas de coupure réseau

### 2. Synchronisation périodique (repli)

Quand le montage natif n'est pas disponible (backend tiers cassé,
maintenance en amont, etc.), un mode de repli s'appuie sur le CLI officiel
Proton pour synchroniser périodiquement un dossier local avec le cloud :

- Synchronisation bidirectionnelle (nouveautés locales → cloud, nouveautés
  cloud → local)
- Reprise automatique après interruption (rien n'est retransféré inutilement)
- Détection de conflit par nom (voir limites dans `ARCHITECTURE.md`)

Les deux chemins partagent la même infrastructure de surveillance et
d'alerte, et peuvent être retentés/basculés à tout moment sans perte de
configuration.

## Sécurité et confidentialité

- Aucun chiffrement supplémentaire imposé par défaut : le contenu reste
  lisible nativement depuis les autres appareils (mobile, web, autres PC)
  connectés au même compte
- Les identifiants du compte ne transitent jamais par un outil tiers ou un
  assistant automatisé — l'authentification se fait toujours dans un
  terminal contrôlé par l'utilisateur
- Le secret technique nécessaire au fonctionnement non-interactif (mot de
  passe de chiffrement de la configuration) est généré aléatoirement,
  stocké avec des permissions restrictives, et jamais commité dans un
  dépôt de code
- Les identifiants du compte principal, eux, sont gérés par le trousseau
  de sécurité du système d'exploitation quand disponible (voir
  `ARCHITECTURE.md`)

## Fiabilité et surveillance

- **Alerte automatique en cas d'échec** : une notification desktop se
  déclenche au moindre problème (montage tombé, synchronisation échouée) —
  aucune panne ne peut passer inaperçue pendant des semaines
- **Vérification périodique de l'état de santé** : contrôle régulier que
  le montage répond, que le cache local ne dérive pas, et qu'aucune erreur
  ne s'accumule silencieusement dans les journaux
- **Verrouillage anti-collision** : les opérations de synchronisation ne
  se chevauchent jamais entre elles, même en cas de tâche planifiée qui se
  déclenche pendant qu'une précédente tourne encore

## Reproductibilité

- Installation scriptée et idempotente : relancer l'installation ne casse
  rien, elle détecte ce qui est déjà en place
- Aucune dépendance à une machine ou un compte spécifique — chaque
  installation génère ses propres secrets et s'authentifie séparément
- Pensé pour être versionné (Git) et redéployé à l'identique sur plusieurs
  machines

## Migration et décommissionnement d'un service existant

Un outillage optionnel accompagne la transition depuis un autre service de
stockage cloud déjà en place (ex. migration progressive, puis retrait
propre du client concurrent) :

- Migration non destructive par défaut : les données source ne sont
  jamais supprimées automatiquement
- Le retrait d'un client concurrent est une étape volontaire, séparée,
  jamais déclenchée automatiquement — et ne touche jamais aux données
  restant sur le service d'origine, seulement au logiciel client local
