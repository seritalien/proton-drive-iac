# Référence CLI — opérations manuelles

Ce projet automatise l'essentiel, mais il est parfois utile d'interagir
directement avec le CLI officiel `proton-drive` (récupérer un fichier
précis, vérifier un chemin, déboguer). Voici les commandes qui reviennent
le plus souvent, avec les pièges à éviter — non documentés clairement
dans la doc officielle (https://proton.me/support/drive-cli,
https://github.com/ProtonDriveApps/sdk/blob/main/cli/README.md).

## Avant toute commande manuelle : le verrou

Le cache local du CLI ne supporte pas deux invocations simultanées — une
commande manuelle lancée pendant qu'une synchronisation planifiée tourne
échouera avec `SQLiteError: database is locked`. Vérifiez d'abord :

```bash
pgrep -fa "proton-drive filesystem"
```

Rien affiché = libre. Si une invocation tourne déjà, attendez qu'elle
termine (ou consultez `~/.local/state/proton-drive-cli-sync.log` pour
suivre sa progression) avant de lancer une commande manuelle.

## Le piège du chemin racine

Toutes les commandes qui prennent un chemin distant doivent commencer par
`/my-files` (le dossier "Mes fichiers" de Proton Drive) — `/` seul ne
liste que les sections virtuelles (`/my-files`, `/photos`, `/trash`...) et
n'est pas accepté comme cible d'upload/download.

```bash
# Fonctionne
proton-drive filesystem list "/my-files/Documents"

# Échoue : "Path / is not supported" / "Path Documents/x not supported"
proton-drive filesystem list "/Documents"
```

## Lister le contenu d'un dossier

```bash
proton-drive filesystem list "/my-files/Documents"
```

Sortie JSON exploitable (utile pour scripter) :
```bash
proton-drive filesystem list "/my-files/Documents" --json | jq -r '.[] | select(.name.ok) | .name.value'
```
Le champ `name` est encapsulé dans un objet `{"ok": true, "value": "..."}`
plutôt qu'une simple chaîne — un `jq '.[].name'` naïf ne suffit pas.

## Télécharger un fichier ou dossier précis

```bash
proton-drive filesystem download "/my-files/Documents/mon-fichier.pdf" ~/ProtonDrive/Documents
```

Le dernier argument est le dossier LOCAL de destination (pas le nom du
fichier) — le nom d'origine est conservé.

## Envoyer un fichier ou dossier précis

```bash
proton-drive filesystem upload -f skip -d merge ~/ProtonDrive/Documents/nouveau.pdf "/my-files/Documents"
```

`-f skip` (fichiers) et `-d merge` (dossiers) évitent d'écraser ce qui
existe déjà côté cloud sous le même nom — voir `docs/ARCHITECTURE.md`
pour les limites de cette résolution de conflit par nom.

## Vérifier l'authentification

```bash
proton-drive filesystem list / &>/dev/null && echo "authentifié" || echo "non authentifié"
```

## Suivre la progression d'une synchronisation en cours

```bash
tail -f ~/.local/state/proton-drive-cli-sync.log
```

Le CLI n'expose pas de compteur "reste X Go à transférer" — seulement un
résumé cumulé par appel (`Transfer summary: Uploaded/Downloaded: N items
(X GiB)`). Pour une estimation grossière : comparer la taille totale
locale (`du -sh ~/ProtonDrive`) aux volumes déjà confirmés transférés dans
le journal — approximatif, pas un vrai indicateur de progression.
