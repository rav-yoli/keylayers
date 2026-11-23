# Publier une nouvelle version de KeyLayers

Ce guide part du dépôt local de KeyLayers sous Windows et des commandes PowerShell dans VS Code. Il utilise `1.0.2` comme exemple. Remplace cette valeur par la version que tu comptes publier.

Pousser un tag de version déclenche **Package KeyLayers**. Le workflow construit le ZIP, le joint à une release GitHub, puis envoie la même archive sur CurseForge en type **Release**. CurseForge traite ensuite le fichier selon son processus d’approbation.

## 1. Préparer la version

Dans le terminal à la racine du dépôt, vérifie la branche et l’état du dossier.

```powershell
git status --short --branch
git var GIT_COMMITTER_IDENT
```

Travaille sur `main`. L’identité de commit et du tag annoté doit être **Rav Yoli**, avec l’adresse `noreply` du compte `rav-yoli`. Avant de commencer les modifications, si ton dossier est propre, récupère les derniers commits sans créer de commit de fusion.

```powershell
git pull --ff-only origin main
```

Mets à jour les références à la version dans les fichiers suivants.

| Fichier | Modification |
| --- | --- |
| `KeyLayers by Rav Yoli.toc` | Passe `## Version:` à `1.0.2`. |
| `Core.lua` | Mets à jour la version de secours dans `addon.version`. |
| `README.md` | Mets à jour la version dans le titre si elle y figure. |

Teste les changements en jeu. Pour une nouvelle version de **WoW Forever**, vérifie aussi la compatibilité et aligne `## Interface:` dans le `.toc` et la version recherchée par **Resolve CurseForge game version** dans `.github/workflows/package.yml`. Pour une sortie qui cible toujours WoW Forever **1.60.1**, ces deux réglages n’ont pas besoin d’être modifiés.

## 2. Committer et pousser `main`

Ajoute les fichiers modifiés pour la sortie. L’exemple ci-dessous couvre les trois fichiers de version. Ajoute également les fichiers qui contiennent tes changements et, si tu l’as modifié, le workflow. Vérifie la liste et le diff avant de committer.

```powershell
$Version = "1.0.2"

git add -- "KeyLayers by Rav Yoli.toc" Core.lua README.md
git diff --cached --name-status
git diff --cached
git commit -m "Prepare KeyLayers $Version"
git push origin main
```

Vérifie que le push s’est terminé correctement. Si tu as modifié le workflow ou la version du jeu, lance d’abord **Actions → Package KeyLayers → Run workflow** sur `main`. Ce test construit le ZIP et vérifie que la version du jeu est trouvée sur CurseForge. Il ne publie aucun fichier.

## 3. Créer et pousser le tag

Dans le même terminal, vérifie que le dernier commit est celui que tu veux publier. Si tu as rouvert PowerShell, redéfinis `$Version`.

```powershell
git status --short --branch
git log -1 --oneline
```

Vérifie que le tag n’existe ni en local ni sur GitHub. Les deux commandes de recherche doivent se terminer sans afficher de tag ni d’erreur.

```powershell
$Tag = "v$Version"

git tag --list "$Tag"
git ls-remote --tags origin "refs/tags/$Tag"
```

Crée un tag annoté sur le commit courant, vérifie le commit qu’il désigne, puis pousse ce tag seul.

```powershell
git tag -a "$Tag" -m "KeyLayers $Version"
git show --no-patch "$Tag"
git push origin "refs/tags/$Tag"
```

Le fichier attendu est `KeyLayers-by-Rav-Yoli-1.0.2.zip`. Le ZIP contient un dossier `KeyLayers by Rav Yoli` avec le `.toc`, les fichiers de l’addon, `Media`, `LICENSE` et `NOTICE`.

## 4. Vérifier la publication

1. Dans [GitHub Actions](https://github.com/rav-yoli/keylayers/actions), ouvre l’exécution du **tag** et vérifie **Build and validate ZIP**, **Publish GitHub release** et **Upload ZIP to CurseForge**. La dernière étape affiche le **CurseForge file ID** quand l’API a accepté l’envoi.
2. Dans [GitHub Releases](https://github.com/rav-yoli/keylayers/releases), vérifie que le ZIP de ta version est bien joint à la release. Complète les notes si nécessaire. CurseForge affiche un lien vers ces notes.
3. Dans l’onglet **Files** du projet CurseForge, vérifie la présence du ZIP, le type **Release** et la version de WoW Forever. L’envoi accepté et la mise en ligne après modération sont deux états distincts.

Le tag historique `v1.0.1b` est exclu de l’envoi automatique à CurseForge, où son ZIP a déjà été soumis manuellement.

## Si une étape échoue

- **Avant la création de la release GitHub**. Ouvre l’étape rouge. Si l’échec est temporaire et que le tag pointe vers le bon commit, tu peux relancer l’exécution. Une relance reprend le même commit. Une correction du contenu nécessite un nouveau commit et un nouveau numéro de version si le tag est déjà en ligne.
- **GitHub est publié, mais l’envoi CurseForge a échoué**. Vérifie d’abord **Files** pour voir si le ZIP est arrivé malgré l’erreur. S’il est absent, récupère le ZIP joint à la GitHub Release et ajoute-le manuellement sur CurseForge. Le workflow actuel essaie de créer la release GitHub à chaque exécution sur un tag et s’arrête si elle existe déjà.
- **Erreur de jeton ou de version du jeu**. Vérifie que le secret GitHub `CF_API_TOKEN` existe et que la version de WoW Forever ciblée par le workflow figure dans CurseForge. Le jeton reste dans les secrets du dépôt.

[Documentation Git sur les tags annotés](https://git-scm.com/docs/git-tag) · [Relancer une exécution GitHub Actions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)
