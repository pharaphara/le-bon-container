<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/brand/banner-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/brand/banner-light.png">
  <img alt="le bon container. Il a la tête de l'emploi. MCP server, headed Chromium, Docker." src="assets/brand/banner-light.png" width="100%">
</picture>

**Français** · [English](README.en.md)

# le bon container

**Il a la tête de l'emploi.**

Explorer les annonces [Leboncoin](https://www.leboncoin.fr) avec une IA, dans un
vrai navigateur, à travers [MCP](https://modelcontextprotocol.io).

![build](https://github.com/pharaphara/le-bon-container/actions/workflows/build.yml/badge.svg)

Une application à installer sur votre machine, ou un conteneur si vous préférez.
Neuf outils, et des résultats exploitables par un assistant : les repères de marché
d'abord, un tableau compact ensuite, le détail complet sur le disque, et des
numéros d'annonces qui ne bougent jamais.

```
search "vtt electrique", place 12, price max 1500

search "vtt-electrique-8778" | 47 announced | 46 collected | 1 calls
prices: median 915 EUR, middle half 500 EUR to 1 250 EUR, range 30 EUR to 1 500 EUR
market: 45 private, 1 pro, median age 118 d, 6 bumped since first posted
---
  n      price  place              age   by   title
  1    1 050 €  Auriac-Lagast (1…  14 j  P    VTT electrique
  2      800 €  Rodez (12)         50 j  P    Vtt electrique giant
  3    1 400 €  Nauviale (12)      30 j  P    Vtt electrique
  …
!! condition the site applied: global_BDC
- more: results(offset=25) for the remaining 21
```

Les catégories et les valeurs de filtres se disent avec les mots du site
(« Voitures », « électrique », « particulier »). Les outils répondent en anglais,
comme le code. Seule la documentation est
bilingue.

## Installation

Deux façons, et la première ne demande rien d'autre que l'application elle-même.

### Sur votre ordinateur, Windows ou Mac

Trois étapes, aucune ligne de commande.

**1. Téléchargez le fichier qui correspond à votre machine.**

| Votre machine | Le fichier |
|---|---|
| Windows | [l'installeur `.msi`](https://github.com/pharaphara/le-bon-container/releases/download/edge/le-bon-container-edge-windows-x64.msi) |
| Mac avec une puce Apple, M1 à M4 | [`le-bon-container-macos-arm64.dmg`](https://github.com/pharaphara/le-bon-container/releases/download/edge/le-bon-container-edge-macos-arm64.dmg) |
| Mac avec un processeur Intel | [`le-bon-container-macos-x64.dmg`](https://github.com/pharaphara/le-bon-container/releases/download/edge/le-bon-container-edge-macos-x64.dmg) |

Si vous ne savez pas quel Mac vous avez : menu Pomme, « À propos de ce Mac ». Une
ligne « Puce » veut dire Apple, une ligne « Processeur » veut dire Intel.

Il n'y a rien d'autre à installer avant : ni Docker, ni Java. Comptez une centaine
de mégaoctets à télécharger, et autant sur le disque.

**2. Ouvrez-le, et passez l'avertissement du système.**

Il y en aura un, et ce n'est pas le signe que quelque chose cloche : ce logiciel
n'est signé par aucun compte développeur payant, et les deux systèmes traitent cela
comme n'importe quel programme qu'ils ne connaissent pas.

- **Windows** : double-cliquez sur le `.msi`. Si « Windows a protégé votre
  ordinateur » apparaît, cliquez « Informations complémentaires », puis « Exécuter
  quand même ». Aucun mot de passe administrateur n'est demandé : l'installation se
  fait pour votre compte.
- **Mac** : ouvrez le `.dmg`, glissez l'application dans Applications, puis
  lancez-la. macOS refuse au premier essai. Ouvrez alors Réglages Système,
  Confidentialité et sécurité, descendez tout en bas, et cliquez « Ouvrir quand
  même ».

**3. Dites à votre assistant où le trouver.**

Cet outil ne se pilote pas tout seul : il met neuf outils à la disposition d'un
assistant qui sait parler [MCP](https://modelcontextprotocol.io), Claude en
application de bureau par exemple. Dans la configuration des serveurs MCP de votre
assistant, ajoutez ceci.

Sur Windows, en remplaçant `VOUS` par votre nom d'utilisateur :

```json
{ "mcpServers": { "lbc": {
  "command": "C:\\Users\\VOUS\\AppData\\Local\\le-bon-container\\le-bon-container.exe",
  "args": ["--stdio"] } } }
```

Sur Mac :

```json
{ "mcpServers": { "lbc": {
  "command": "/Applications/le-bon-container.app/Contents/MacOS/le-bon-container",
  "args": ["--stdio"] } } }
```

Redémarrez l'assistant, et vous pouvez lui demander, en français : « cherche des
VTT électriques à moins de 1 500 € autour de Rodez ». Vous n'avez rien à lancer
vous-même : c'est l'assistant qui démarre l'outil quand il en a besoin, et qui
l'arrête avec lui.

**Une chose doit déjà être sur la machine** : Google Chrome, Microsoft Edge ou
Chromium. L'outil se sert du navigateur que vous avez plutôt que d'en télécharger
un à lui, et ce n'est pas une économie : [c'est ce qui fait la différence entre
lire le site et se faire
arrêter](#comment-le-navigateur-est-démarré-et-pourquoi-ça-compte-plus-que-tout).

### La première fois, un clic qui vous revient

Au démarrage, une fenêtre de navigateur s'ouvre toute seule. Allez sur
[leboncoin.fr](https://www.leboncoin.fr) dedans, et si le site affiche un contrôle
« je ne suis pas un robot », passez-le. Connectez-vous à votre compte si vous le
souhaitez.

C'est la seule chose qu'aucun logiciel ne devrait faire à votre place, et ce projet
ne la contourne pas : rien ici ne falsifie une empreinte de navigateur, rien
n'achète la résolution d'un captcha. Un clic, une fois, et le profil s'en souvient
— y compris après un redémarrage.

Ce n'est pas facultatif, et il vaut la peine de savoir pourquoi. Mesuré sur un
profil neuf : le site affiche ses pages sans broncher, mais refuse les appels de
données par un 403 portant un marqueur anti-robot, et au bout de quelques requêtes
il finit par contrôler la page elle-même. Un profil tout neuf n'a simplement aucune
validation. Savoir si un compte apporte quelque chose en plus n'a pas été mesuré,
donc ce document ne l'affirme pas.

### Avec Docker, sur un serveur, un NAS, une machine partagée

```bash
docker compose up -d
```

Puis on branche son client dessus : voir [brancher un
client](#brancher-un-client), pour Claude Code, Claude, ChatGPT et Codex.

Rien à compiler et aucun JDK à installer : l'image est construite et publiée par
l'intégration continue.

La première fois, lancez plutôt `docker compose up` sans `-d` : le conteneur
affiche un message d'accueil avec les deux adresses et l'état du profil. Ensuite,
`docker compose logs lbc` le redonne à tout moment. Docker n'affiche rien de
l'intérieur d'un conteneur démarré en arrière-plan, c'est une limite de Docker et
non un oubli.

Le clic de tout à l'heure se fait ici à travers une page : ouvrez
<http://localhost:7900>, vous y regardez le navigateur du conteneur, et vous passez
le contrôle dedans.

## L'installation sur le poste, en détail

Ce que l'[installation](#sur-votre-ordinateur-windows-ou-mac) plus haut ne dit pas,
parce qu'elle n'a pas besoin de le dire pour fonctionner.

**Il existe aussi des versions à décompresser**, pour qui préfère ne rien
installer : `…-windows-x64-portable.zip` contient `le-bon-container.exe`, et les
`…-macos-*.zip` contiennent la même `.app` que les images disque. Rien n'est écrit
ailleurs que dans votre dossier de données.

**macOS refuse un numéro de version qui commence par zéro.** L'application affiche
donc un numéro de plus que le projet — `1.1.x` pour un projet en `0.1.x` — et c'est
le nom du fichier qui porte la vraie version.

**Aucun Java à installer** : un runtime taillé aux modules de l'application est
inclus dans chaque fichier. Mesuré au moment de la construction, côté Windows :
100 Mo pour le msi, 99 Mo pour le zip, dont 50 Mo de runtime Java et 33 Mo pour le
Node que Playwright transporte. Les images macOS sont du même ordre, 106 Mo pour
l'Apple Silicon et 109 Mo pour l'Intel. Environ 120 Mo sur le disque après
installation, contre 2,2 Go pour l'image Docker, parce que le navigateur et l'écran
sont déjà là.

**Les mises à jour suivent le même rythme que l'image.** Deux canaux, construits et
publiés par l'intégration continue :

| | Image Docker | Windows et Mac |
|---|---|---|
| À chaque changement sur `main` | `ghcr.io/pharaphara/lbc:latest` | la pré-version [`edge`](https://github.com/pharaphara/le-bon-container/releases/tag/edge) |
| À chaque version publiée | `ghcr.io/pharaphara/lbc:0.1.0` | la release numérotée |

Les adresses de l'`edge` ne changent jamais, et servent toujours la dernière
construction. Ce sont celles des liens plus haut :

```
…/releases/download/edge/le-bon-container-edge-windows-x64.msi
…/releases/download/edge/le-bon-container-edge-windows-x64-portable.zip
…/releases/download/edge/le-bon-container-edge-macos-arm64.dmg
…/releases/download/edge/le-bon-container-edge-macos-x64.dmg
```

Chaque construction `edge` porte un numéro de version plus élevé que la précédente,
et c'est volontaire : Windows décide d'installer ou de ne rien faire en comparant
les versions, donc deux installeurs qui s'appellent tous les deux `0.1.0` sont pour
lui le même produit déjà installé. Avec un numéro qui monte, l'installeur
s'installe par-dessus le précédent sans rien désinstaller.

En revanche **rien ne se met à jour tout seul sur votre machine** : c'est un
installeur à relancer, ou un dossier à remplacer. Le profil et les recherches
vivent ailleurs, donc une réinstallation ne touche ni votre session ni vos données.

**Sur la méfiance des deux systèmes**, dont les gestes sont donnés plus haut : un
certificat de signature Windows coûte quelques centaines d'euros par an, et la
notarisation Apple demande un compte développeur. Ce projet n'a ni l'un ni l'autre,
et le dire est plus honnête que de faire comme si l'avertissement n'existait pas.
En ligne de commande sur Mac, `xattr -dr com.apple.quarantine
/Applications/le-bon-container.app` fait la même chose que le bouton des réglages.

Ce que l'installation sur le poste change par rapport au conteneur, et c'est plutôt
à son avantage :

| | Conteneur | Installation sur le poste |
|---|---|---|
| Navigateur | un Chromium téléchargé, profil neuf | votre Chrome ou Edge déjà installé |
| Voir la page | <http://localhost:7900>, un visualiseur | la fenêtre est sur votre bureau |
| Profil et données | des volumes Docker | `%LOCALAPPDATA%\le-bon-container\` ou `~/Library/Application Support/le-bon-container/` |
| Branchement | HTTP sur `localhost:8788` | HTTP, ou l'entrée standard et le client lance tout |
| À installer d'abord | Docker | rien |

Le navigateur s'ouvre sur un **profil à part**, pas celui de votre navigation
quotidienne : Chrome refuse d'ouvrir un port de débogage sur un profil déjà ouvert,
et mélanger les deux serait de toute façon désagréable.

Pour arrêter : fermez la fenêtre de console sous Windows, quittez l'application sur
Mac, ou fermez l'assistant si c'est lui qui l'a lancée. Le navigateur se ferme avec,
et proprement, donc pas de bandeau « restaurer la session » au démarrage suivant.

Pour construire soi-même, avec un JDK 21 :

```powershell
mvn -B -DskipTests package
pwsh package/windows/package.ps1          # -Type msi ou -Type portable
```

```bash
mvn -B -DskipTests package
./package/macos/package.sh                # --type dmg ou --type portable
```

Le msi demande [WiX 3](https://github.com/wixtoolset/wix3/releases) ; sans lui, le
script le dit et produit quand même le zip. Chaque script construit pour la machine
sur laquelle il tourne : jpackage ne sait pas faire autrement.

## Brancher un client

Deux façons d'être branché, et elles ne servent pas la même chose.

**En HTTP**, sur `http://localhost:8788/mcp` : un serveur qui tourne, que plusieurs
clients peuvent partager, et dont le navigateur et le profil restent chauds entre
deux conversations. C'est ce que fait le conteneur, et c'est le seul mode qui
convienne à un ChatGPT ou à une machine distante.

**Sur l'entrée standard**, avec `--stdio` : c'est le client qui lance le programme,
donc il n'y a rien à démarrer d'avance et rien qui traîne derrière. Sur un poste
avec l'installeur Windows ou Mac, c'est généralement ce qu'on veut.

### En HTTP

Le serveur écoute sur `http://localhost:8788/mcp`. Voici les quatre cas les plus
courants.

**Claude Code**

```bash
claude mcp add --transport http lbc http://localhost:8788/mcp
```

**Claude, application de bureau**

Dans le fichier de configuration des serveurs MCP :

```json
{ "mcpServers": { "lbc": { "type": "http", "url": "http://localhost:8788/mcp" } } }
```

Les versions récentes permettent aussi d'ajouter un connecteur personnalisé
depuis les réglages, en collant la même adresse.

**ChatGPT**

Il faut une adresse **publique en HTTPS** : ChatGPT n'atteindra jamais votre
`localhost`. Mettez donc un reverse proxy avec TLS devant le port 8788, par
exemple `lbc.exemple.org`, puis ajoutez-le comme connecteur personnalisé dans les
réglages de votre compte. La disponibilité de cette fonction dépend de votre offre
et de vos réglages, ce document ne peut pas le savoir à votre place. Et n'exposez
rien sans authentification devant : ces outils pilotent un navigateur qui porte
votre session.

**Codex**

Dans `~/.codex/config.toml` :

```toml
[mcp_servers.lbc]
command = "npx"
args = ["-y", "mcp-remote", "http://localhost:8788/mcp"]
```

Cette forme passe par une passerelle, donc elle marche quelle que soit la version.
Si la vôtre accepte directement une adresse HTTP, la déclarer ainsi évite la
passerelle.

**N'importe quel autre client qui ne parle que stdio** se branche de la même
façon, par une passerelle du type `mcp-remote` pointée sur la même adresse — ou,
avec l'installation sur le poste, sans passerelle du tout : voir juste en dessous.

### Sur l'entrée standard

Le chemin du programme, suivi de `--stdio`. Rien à lancer d'avance : le client
démarre le serveur quand il en a besoin, et l'arrête en même temps que lui. C'est
ce que fait l'installation sur le poste, et la configuration pour Claude en
application de bureau est donnée [tout en
haut](#sur-votre-ordinateur-windows-ou-mac).

**Claude Code** :

```bash
claude mcp add lbc -- /Applications/le-bon-container.app/Contents/MacOS/le-bon-container --stdio
```

**Codex**, dans `~/.codex/config.toml` :

```toml
[mcp_servers.lbc]
command = "/Applications/le-bon-container.app/Contents/MacOS/le-bon-container"
args = ["--stdio"]
```

Dans ce mode, la sortie standard appartient au protocole : une ligne de journal
qui atterrirait là ne serait pas du bruit, mais une erreur d'analyse à l'autre
bout. Les journaux vont donc dans un fichier, et le message d'accueil sur la
sortie d'erreur, que les clients savent afficher :

```
%LOCALAPPDATA%\le-bon-container\lbc.log
~/Library/Application Support/le-bon-container/lbc.log
```

Le navigateur s'ouvre quand le client démarre le serveur, et se ferme avec lui. Si
vous lancez deux clients, le second se rattache au navigateur du premier plutôt
que d'en ouvrir un deuxième.

## Les outils

| Outil | Ce qu'il fait |
|---|---|
| `search` | Collecte une recherche. Un rendu de page, puis la pagination par appels de données. Rend les repères, puis un tableau. |
| `results` | Relit ce qui a été collecté : filtrer et trier, hors ligne, autant de fois qu'on veut. |
| `ad` | Tout sur une annonce, sans réseau. `refresh=true` va revérifier sur le site. |
| `stats` | Le marché en chiffres, éventuellement groupé par marque, année, ville ou vendeur. |
| `filters` | Ce que le site a retenu d'une URL de recherche, et ce qu'il a jeté en silence. |
| `categories` | Les 45 catégories mesurées, ou le sondage d'un identifiant à la demande. |
| `searches` | Ce qui est sur le disque, et la recherche que les autres outils visent par défaut. |
| `forget` | Supprime une recherche et ses annonces. |
| `status` | Comment le conteneur est câblé, et où cliquer si un mur apparaît. |

## Comment ça marche

Quatre choses ont été mesurées plutôt que supposées, et elles font toute la
conception.

**La page livre sa propre charge de recherche.** Une page de résultats embarque la
requête exacte que le site a dérivée de l'URL. Donc rien n'est inventé : on
construit une URL avec des paramètres mesurés un par un contre le total que le site
annonce, on la rend une fois, puis on rejoue sa propre charge pour parcourir le
reste. Le rendu est le poste coûteux, et il n'a lieu qu'une fois.

**La pagination se fait sur `offset` seul.** Le `pivot` que le site renvoie
ressemble à un curseur mais n'est qu'une liste d'identifiants déjà montrés : le
rejouer depuis l'offset zéro rend les mêmes annonces. `max_pages` vaut 2 pour 122
annonces, donc il est affiché et jamais utilisé comme borne.

**La liste porte déjà tout.** Mesuré sur une annonce : 6588 caractères de
description dans les résultats de recherche, exactement autant que sur sa propre
page, avec tous les attributs et toutes les photos. Donc `ad` ne coûte rien et ne
touche pas au réseau. Visiter une annonce n'apprend qu'une seule chose que la liste
ignore : si le prix a bougé ou si elle est vendue depuis.

**L'API se répète.** Trois réponses totalisant 224 lignes ne portaient que 120
identifiants distincts. Le dédoublonnage n'est pas une précaution ici, c'est une
obligation, et le nombre affiché est toujours celui des annonces uniques.

**Et quand les appels de données sont refusés, les pages rendues marchent
encore.** Tant qu'un profil n'a pas de validation, on lit ce que la page rend
elle-même, une trentaine d'annonces à la fois, et on pagine par l'URL. C'est plus
lent, un rendu par page, et la réponse le dit en toutes lettres au lieu de faire
semblant. Passez le contrôle une fois et la voie rapide s'ouvre d'elle-même.

Et une dernière chose, qui ne tient pas au site : **les numéros ne bougent
jamais.** Une annonce garde le numéro reçu la première fois qu'on l'a vue.
`ad(number=7)` désigne la même annonce dix messages plus tard, après deux pages de
plus et un tri par prix. Cette seule propriété rend supportable une longue
conversation avec une place de marché.

## Les catégories sont mesurées, pas recopiées

Quarante-cinq, et chaque identifiant vient des données du site plutôt que des notes
de quelqu'un. Chaque annonce porte à la fois son `category_id` et son
`category_name`, donc parcourir le site trié par date rend des paires canoniques à
la douzaine : 210 annonces sur six pages en ont donné 44 d'un coup.

Cette méthode a immédiatement corrigé deux identifiants qui avaient l'air justes et
ne l'étaient pas. Les jouets, c'est 41, alors que 40 est Collection. Le jardin,
c'est 52, alors que 32 est l'équipement industriel. L'un comme l'autre auraient
rendu un marché vide sans la moindre erreur, et c'est bien le défaut qui compte
ici : un mauvais identifiant n'échoue pas, il ne trouve simplement rien.

Un nom jamais mesuré est donc refusé plutôt qu'utilisé. N'importe quel identifiant
numérique fonctionne directement, et `categories(verify=["70"])` en sonde un sur le
champ et vous dit comment le site l'appelle.

## Aucun déguisement, jamais

Le mur sur ce genre de site est un défi JavaScript, pas une empreinte. Six sessions
sur quatre familles d'empreintes maquillées ont toutes été refusées, là où un vrai
navigateur avec une vraie session est passé sans encombre. Mieux se déguiser est
donc la mauvaise dimension.

Alors ce conteneur pilote un vrai navigateur avec votre propre session. Il ne
bricole pas `navigator`, il ne falsifie pas d'agent utilisateur, il ne passe même
pas le drapeau qui masque l'automatisation, et il n'appelle jamais de service de
résolution de captcha. Devant un contrôle il attend, parce qu'un vrai navigateur en
vient souvent à bout tout seul, puis il coche au plus une case. Un puzzle est
l'endroit où il s'arrête et vous renvoie vers <http://localhost:7900>. Un test
impose tout cela : quinze motifs sont bannis du dépôt, et le détecteur est
lui-même éprouvé contre un déguisement connu.

## Comment le navigateur est démarré, et pourquoi ça compte plus que tout

C'est la découverte la plus utile du projet, et elle a été mesurée en comparant ce
conteneur à un navigateur qui lit ce genre de site tous les jours depuis des mois
sans jamais se faire restreindre.

| Vu depuis une page | Navigateur démarré par la bibliothèque | Navigateur démarré normalement |
|---|---|---|
| `navigator.webdriver` | `true` | `false` |
| `navigator.plugins` | 0 | 5 |

Laisser Playwright lancer le navigateur ajoute le drapeau d'automatisation, et la
page le voit. Démarrer un navigateur de bureau ordinaire avec un port de débogage
ouvert, puis simplement s'y rattacher, ne l'ajoute pas. C'était la seule différence
structurelle entre les deux installations.

C'est pourquoi l'application démarre elle-même un navigateur ordinaire, avec un
port de débogage ouvert, et s'y rattache. C'est ce que fait `LBC_BROWSER: attach`.
Rien n'est falsifié et rien n'est masqué : un drapeau n'est simplement pas ajouté.
On ne bricole pas `navigator`, on ne passe pas le fameux drapeau qui masque
l'automatisation, et la différence tient uniquement à la façon de lancer le
programme.

Lequel elle démarre dépend de la machine, et l'ordre n'est pas innocent : votre
Chrome, votre Edge ou votre Chromium d'abord, le Chromium de Playwright en dernier.
Un navigateur que quelqu'un a installé et avec lequel il lit le web porte un
profil, un historique et une réputation ; la copie téléchargée par une
bibliothèque de test ne porte rien de tout cela, et les sites qui distribuent des
murs savent faire la différence. Dans le conteneur ce dernier est le seul présent,
et c'est une raison de plus de préférer l'installation Windows si vous avez le
choix.

Si un navigateur écoute déjà sur le port 9222, c'est celui-là qui est utilisé, sans
rien démarrer : le vôtre, avec votre session, vaut toujours mieux que le nôtre.

`LBC_BROWSER: launch` rend l'ancien comportement, où la bibliothèque lance le
navigateur elle-même : plus simple, et plus bruyant. `LBC_BROWSER: off` ne démarre
rien du tout.

## Rien en silence

Chaque réduction est comptée et montrée, sur une ligne commençant par `!!`. Un
critère que le site a ignoré, une annonce écartée parce qu'elle venait d'une autre
rubrique, un doublon, une collecte arrêtée avant la fin, une recherche servie
depuis le disque : chacune produit un chiffre dans la réponse.

C'est le défaut contre lequel ce projet est bâti. Un tableau qui a perdu un tiers de
ses lignes sans le dire se lit exactement comme un marché étroit, et un assistant
n'a aucun moyen de faire la différence.

## Ce qu'il faut pour le faire tourner

Mesuré, pas estimé, sur une machine à six cœurs.

| | Mesure |
|---|---|
| Image | 2,2 Go |
| RAM au repos | 467 Mio, navigateur allumé compris |
| RAM pendant une recherche | 960 Mio au plus haut |
| CPU au repos | 0,5 % |
| Données | environ 8 Ko par annonce, soit 8 Mo pour mille |

L'installation Windows demande bien moins de disque, parce que tout ce qu'elle ne
transporte pas est déjà sur la machine : le navigateur et l'écran.

| | Mesure |
|---|---|
| Installeur msi | 100 Mo |
| Zip portable | 99 Mo |
| Dont runtime Java | 50 Mo, taillé aux modules chargés, contre 286 Mo pour un JDK entier |
| Sur le disque | environ 120 Mo |

La mémoire n'a pas été mesurée sur Windows, et ce document ne l'inventera pas :
c'est le même navigateur et la même machine Java, sans le serveur d'affichage ni
le visualiseur.

En pratique : **1,5 Go de RAM pour le conteneur, 3 Go de disque, deux cœurs**, et
pas de carte graphique. Si la machine est déjà chargée, `LBC_BROWSER: launch` ne
garde pas de navigateur allumé entre deux appels, au prix d'un démarrage à chaque
session et d'un navigateur qui annonce être piloté.

Un conteneur qui embarque un vrai navigateur ne peut pas être petit, et voici où
vont les 2,2 Go : 780 Mo pour Chromium et ses bibliothèques, 520 Mo pour le
serveur d'affichage et le visualiseur, 250 Mo pour la machine Java, le reste pour
l'application. La première piste pour alléger est une variante sans visualiseur,
pour qui se rattache à son propre navigateur : elle enlève 520 Mo d'un coup.

## Configuration

Tout a une valeur par défaut qui fonctionne. On ne règle que ce dont on a besoin,
dans `compose.yaml` pour le conteneur, en variables d'environnement pour une
installation Windows.

| Variable | Défaut | Ce que c'est |
|---|---|---|
| `LBC_DATA` | `/data`, sinon `%LOCALAPPDATA%\le-bon-container\data` | Un dossier par recherche. À monter pour conserver ses recherches. |
| `LBC_PROFILE` | `/profile`, sinon `…\le-bon-container\profile` | Le profil du navigateur, pour qu'une connexion survive à un redémarrage. |
| `LBC_BROWSER` | `attach` | `attach` démarre un navigateur ordinaire et s'y rattache, `launch` laisse la bibliothèque le lancer, `off` ne démarre rien. |
| `LBC_HEADLESS` | `false` | Un humain doit pouvoir voir la page pour passer un contrôle. |
| `LBC_CDP_URL` | vide | Se rattacher à un navigateur déjà lancé au lieu d'en démarrer un. |
| `LBC_VNC_URL` | l'adresse du visualiseur dans l'image, vide ailleurs | Où envoyer un humain quand un mur demande un clic. Vide, les messages parlent de la fenêtre du bureau. |
| `LBC_VNC_PASSWORD` | vide | À renseigner avant d'exposer le port 7900 ailleurs que sur la machine locale. |
| `LBC_VIEWER` | `on` | `off` supprime l'affichage et le visualiseur. Sans objet hors conteneur. |
| `LBC_PACE_CALL_MIN_MS` | `1500` | Pause la plus courte entre deux appels de données. |
| `LBC_PACE_CALL_MAX_MS` | `3500` | La plus longue, tirée au hasard entre les deux. |
| `LBC_PACE_RENDER_MIN_MS` | `6000` | Entre deux rendus de page, qui coûtent bien plus cher au site. |
| `LBC_PACE_RENDER_MAX_MS` | `10000` | Idem, borne haute. |
| `LBC_PACE_CALLS_PER_MINUTE` | `20` | Plafond, quoi que disent les pauses. |
| `LBC_PACE_PAGES_MAX` | `20` | Butée dure sur le nombre de pages par collecte. |
| `LBC_PACE_RENDERED_PAGES_MAX` | `3` | Pages par appel sur la voie lente. |
| `LBC_MAX_ADS` | `2000` | Butée dure sur le nombre d'annonces par recherche. |
| `SERVER_PORT` | `8788` | Le port d'écoute de MCP, en HTTP. |

Et un seul argument en ligne de commande, `--stdio`, qui remplace le serveur HTTP
par un dialogue sur l'entrée standard : voir [brancher un
client](#sur-lentrée-standard).

**Apportez votre navigateur.** Avec `LBC_CDP_URL` pointant sur un Chromium déjà
lancé avec le pilotage à distance activé, le conteneur s'y rattache et utilise son
premier contexte, c'est-à-dire le vrai profil avec la vraie session. Rien n'est
lancé et rien n'est fermé : le navigateur est le vôtre.

**Derrière un reverse proxy.** Le port 7900 est une page web, donc n'importe quel
reverse proxy peut la mettre derrière un nom à vous, par exemple
`lbc.exemple.org`. Renseignez `LBC_VNC_PASSWORD` d'abord : qui ouvre cette page
pilote un navigateur qui porte votre session, et c'est exactement pour cela que le
fichier compose lie les deux ports à la machine locale tant que vous n'en décidez
pas autrement.

**Derrière un VPN.** Rien à coder : Docker sait déjà le faire avec
`network_mode: "service:<vpn>"`, en déplaçant la publication des ports sur le
conteneur VPN. Mais réfléchissez avant, parce que c'est souvent contre-productif
ici. Une sortie de VPN commercial est une adresse de centre de données, et la
réputation de l'adresse est précisément ce que les contrôles anti-robot notent :
le mur apparaîtra plus souvent, pas moins. Le cas qui a du sens est l'inverse, un
VPN vers votre propre réseau, qui garde une adresse résidentielle et permet de
faire tourner le conteneur ailleurs tout en sortant de chez vous.

**Où vivent vos données.** Un dossier par recherche sous `/data` :

```
/data/<recherche>/
  search.json    l'url, la charge que le site en a dérivée, les totaux, où la pagination s'est arrêtée
  ads.jsonl      une ligne par annonce, l'objet du site lui-même, numéroté
  skipped.jsonl  les annonces écartées, avec le motif, pour vérifier que le filet était juste
  seen.tsv       le registre identifiant vers numéro, et c'est pourquoi les numéros ne bougent pas
  ads/<id>.json  ce qu'une revérification a ramené
```

C'est l'objet brut qui est stocké, pas une vue compacte. La description complète y
est de toute façon, et recalculer la vue à la lecture évite des colonnes périmées le
jour où la formule change.

**La cadence se règle dans le compose.** Ce sont les nombres qui décident si le
site vous voit comme un visiteur ou comme une nuisance. Les valeurs par défaut
viennent d'un navigateur qui lit ce genre de site tous les jours depuis des mois :
une à trois secondes entre deux appels, six à dix entre deux rendus de page. Aller
plus vite ne collecte pas plus, ça collecte moins longtemps.

## Si l'accès est temporairement restreint

Ça arrive, et c'est mesuré : un profil sans validation qui insiste finit par voir
« accès temporairement restreint ». Ce n'est pas un contrôle à passer, c'est une
pause à prendre. Cliquer n'y changera rien, et réessayer aggrave les choses.

L'outil le reconnaît et le dit autrement qu'un simple mur : il vous demande de vous
arrêter, pas d'aller cliquer. Deux choses à garder en tête. Votre adresse est
probablement partagée avec vos autres outils, donc insister depuis ce conteneur
dégrade ce qui marche ailleurs. Et la sortie, ce n'est pas un contournement : c'est
un profil avec une vraie session et une cadence plus lente.

## Développement

```bash
mvn verify              # la logique métier : sans navigateur, sans réseau, sur échantillons figés
mvn spring-boot:run     # le lancer sur sa machine
docker build -t lbc .   # l'image
```

```powershell
pwsh package/windows/package.ps1   # le msi et le zip, sur Windows, après un mvn package
```

Lancé à la main, le serveur prend le navigateur de la machine et écrit sous votre
dossier de données : pas besoin de conteneur pour le développement courant.

L'intégration continue ne fait pas que construire : elle installe le msi, monte
l'image disque, démarre le conteneur, et interroge les trois applications ainsi
installées — le navigateur annonce-t-il être piloté, la sortie standard ne porte-t-elle
que du protocole, un navigateur survit-il au serveur. Chaque machine dépose au
passage une capture de ce qu'elle avait à l'écran, jointe au build.

Playwright embarque son propre Node pour cinq plateformes, et c'est ainsi qu'il
garantit la version dont il a besoin. L'image garde celle qu'elle exécute et jette
les quatre autres, soit 155 Mo ; l'installation Windows fait le même tri et passe
de 204 Mo à 35 Mo.

## Feuille de route

**La messagerie par MCP**, en lecture et en réponse, pour qu'un assistant puisse
mener seul une négociation sur un objet. La ligne à tenir est la profondeur contre
la largeur : beaucoup d'échanges dans un même fil, c'est une négociation ; beaucoup
de fils ouverts avec des inconnus, c'est du spam. Les plafonds porteront donc sur
les fils ouverts par jour et non sur les réponses, l'autonomie sera un niveau
explicite et non un défaut, tout ce qui part sera journalisé, et la règle selon
laquelle un assistant n'énonce jamais un fait faux a sa place dans la description
de l'outil, là où elle sera vraiment lue.

**Alléger l'image.** 2,2 Go, c'est le prix d'un vrai navigateur, mais une
partie se récupère. Une variante sans visualiseur enlève 520 Mo pour qui se
rattache à son propre navigateur. Une machine Java taillée sur mesure en enlève
encore une centaine. Et les bibliothèques installées avec Chromium sont un
sur-ensemble de ce qu'il lie vraiment. Premier gain déjà pris : 942 Mo, en
ordonnant deux instructions du Dockerfile pour que le navigateur ne soit pas
stocké deux fois.

**La connexion au site** sans passer par le visualiseur, pour qui préfère mettre
des identifiants dans le fichier compose. Ce restera une option et non le défaut :
un mot de passe de place de marché en clair est un mauvais échange contre un geste
qu'on ne fait qu'une fois.

## Usage responsable

C'est un outil d'automatisation personnelle. Il pilote votre navigateur et votre
session, à un rythme humain, et lit des pages que vous pourriez ouvrir vous-même.
L'accès automatisé est contraire aux conditions d'utilisation du site, donc ce que
vous en faites vous regarde. Gardez-le pour vos propres recherches et vos propres
conversations : il n'existe délibérément aucun moyen d'écrire à plusieurs personnes
à la fois, et il n'y en aura jamais.

## Licence

MIT. Voir [LICENSE](LICENSE).

Projet indépendant, non affilié à Leboncoin.
