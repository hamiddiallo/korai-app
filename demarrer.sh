#!/usr/bin/env bash
# Lance tout Korai pour tester l'application : base PostgreSQL, service IA (serviceIA),
# backend, simulateur iOS et émulateur Android, avec l'app compilée, installée et ouverte.
#
# Utilisation :
#   ./demarrer.sh                 tout lancer (recompile l'app)
#   ./demarrer.sh --sans-build    rouvrir l'app déjà installée, sans recompiler
#   ./demarrer.sh --sans-ios      sans le simulateur iOS (de même : --sans-android)
#   ./demarrer.sh --detache       serveurs laissés en arrière-plan, le script rend la main
#                                 (arrêt : ./arreter.sh) ; utilisé par demarrer-ios.sh et demarrer-android.sh
#
# Sans --detache, Ctrl-C arrête les serveurs lancés par le script ; les émulateurs restent ouverts.
# Autres appareils : variables KORAI_IOS_SIM (identifiant du simulateur) et KORAI_AVD (AVD Android).

set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$ROOT/logs"
BACKEND_PORT=4000
IA_PORT=8000
IOS_SIM="${KORAI_IOS_SIM:-C6806DF1-C63F-436D-BCE2-08DCF00EE124}" # iPhone 17 Pro
AVD="${KORAI_AVD:-Korai_Pixel7_API35}"
IOS_BUNDLE="com.example.koraiFrontend"
ANDROID_PKG="com.example.korai_frontend"
IOS_APP="$ROOT/frontend/build/ios/iphonesimulator/Runner.app"
APK="$ROOT/frontend/build/app/outputs/flutter-apk/app-debug.apk"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$ANDROID_HOME/platform-tools/adb"
EMULATOR="$ANDROID_HOME/emulator/emulator"

BUILD=1 IOS=1 ANDROID=1 DETACHE=0
for arg in "$@"; do
  case "$arg" in
    --sans-build) BUILD=0 ;;
    --sans-ios) IOS=0 ;;
    --sans-android) ANDROID=0 ;;
    --detache) DETACHE=1 ;;
    -h | --aide | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Option inconnue : %s (voir ./demarrer.sh --aide)\n' "$arg" >&2; exit 2 ;;
  esac
done

# ------------------------------------------------------------------ affichage
if [ -t 1 ]; then
  GRAS=$'\033[1m' VERT=$'\033[32m' JAUNE=$'\033[33m' ROUGE=$'\033[31m' PALE=$'\033[2m' FIN=$'\033[0m'
else
  GRAS='' VERT='' JAUNE='' ROUGE='' PALE='' FIN=''
fi
etape() { printf '\n%s%s%s\n' "$GRAS" "$1" "$FIN"; }
ok() { printf '  %s✓%s %s\n' "$VERT" "$FIN" "$1"; }
info() { printf '  %s%s%s\n' "$PALE" "$1" "$FIN"; }
alerte() { printf '  %s!%s %s\n' "$JAUNE" "$FIN" "$1"; }
echec() { printf '\n%s✗ %s%s\n' "$ROUGE" "$1" "$FIN" >&2; exit 1; }

# ------------------------------------------------------------------ outils
# Réessaie une commande chaque seconde jusqu'à réussite : attendre <secondes> <commande…>
attendre() {
  local limite=$1 debut=$SECONDS
  shift
  until "$@" >/dev/null 2>&1; do
    [ $((SECONDS - debut)) -ge "$limite" ] && return 1
    sleep 1
  done
}

port_occupe() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

pg_pret() {
  if command -v pg_isready >/dev/null 2>&1; then pg_isready -q -h localhost -p 5432; else port_occupe 5432; fi
}

# Valeur d'une clé d'un .env, sans guillemets. Sert aux vérifications : jamais affichée.
valeur_env() {
  sed -n "s/^$2=//p" "$1" | tail -n 1 | sed -e "s/^[\"']//" -e "s/[\"'][[:space:]]*\$//" -e 's/[[:space:]]*$//'
}

# Lance une commande dans sa propre session : le Ctrl-C du terminal ne l'atteint pas, et
# `kill -- -PID` arrête tout son groupe (npm → tsx → node, uvicorn…). PID dans DERNIER_PID.
lancer_en_fond() { # lancer_en_fond <journal> <dossier> <commande…>
  local journal=$1 dossier=$2
  shift 2
  (cd "$dossier" && exec python3 -c 'import os, sys
try:
    os.setsid()
except OSError:
    pass
os.execvp(sys.argv[1], sys.argv[1:])' "$@") >"$journal" 2>&1 &
  DERNIER_PID=$!
  disown
}

# Serveurs lancés par ce script (« nom:pid »), arrêtés à la sortie.
LANCES=""
arreter_serveurs() {
  local entree nom pid
  [ -n "$LANCES" ] || return 0
  printf '\n'
  for entree in $LANCES; do
    nom=${entree%%:*} pid=${entree##*:}
    kill -TERM -- "-$pid" 2>/dev/null || continue
    for _ in 1 2 3 4 5 6 7 8 9 10; do # jusqu'à 5 s pour s'arrêter proprement
      kill -0 -- "-$pid" 2>/dev/null || break
      sleep 0.5
    done
    kill -KILL -- "-$pid" 2>/dev/null
    ok "$nom arrêté"
  done
  LANCES=""
  info "Les émulateurs restent ouverts."
}
trap arreter_serveurs EXIT
trap 'exit 130' INT TERM HUP

android_serie() { "$ADB" devices 2>/dev/null | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }'; }
android_demarre() {
  local serie
  serie=$(android_serie)
  [ -n "$serie" ] && [ "$("$ADB" -s "$serie" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]
}
# Après un démarrage à froid, l'émulateur (protégé par un code, pour tester l'empreinte) reste
# verrouillé : aucune app ne peut s'ouvrir tant que le code n'a pas été saisi.
android_deverrouille() { [ "$("$ADB" -s "$SERIE" shell getprop sys.user.0.ce_available 2>/dev/null | tr -d '\r')" = true ]; }
# Écran allumé sur la saisie du code. L'écran de verrouillage se rendort après une dizaine de
# secondes sans saisie : appelé en boucle pendant l'attente, sans effet si l'écran est allumé.
reveiller_android() {
  if "$ADB" -s "$SERIE" shell dumpsys power 2>/dev/null | grep -q 'mWakefulness=Asleep'; then
    "$ADB" -s "$SERIE" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
    "$ADB" -s "$SERIE" shell wm dismiss-keyguard >/dev/null 2>&1
  fi
}
android_deverrouille_sinon_reveiller() { android_deverrouille || { reveiller_android; return 1; }; }

# ------------------------------------------------------------------ vérifications
etape "Vérifications"
for outil in curl lsof python3 npm flutter; do
  command -v "$outil" >/dev/null 2>&1 || echec "Outil introuvable : $outil"
done
[ -d "$ROOT/backend/node_modules" ] || echec "Dépendances du backend absentes : lancez « npm install » dans backend/."
[ -x "$ROOT/serviceIA/backend/.venv/bin/python" ] ||
  echec "Environnement Python de serviceIA absent : voir serviceIA/README.md (« Lancer en développement »)."
[ -f "$ROOT/backend/.env" ] || echec "backend/.env manquant (modèle : backend/.env.example)."
[ -f "$ROOT/serviceIA/backend/.env" ] || echec "serviceIA/backend/.env manquant (modèle : serviceIA/backend/.env.example)."
[ -n "$(valeur_env "$ROOT/serviceIA/backend/.env" MISTRAL_API_KEY)" ] ||
  alerte "MISTRAL_API_KEY vide (serviceIA/backend/.env) : l'avis sur les symptômes sera indisponible."
[ "$(valeur_env "$ROOT/backend/.env" AI_SERVICE_API_KEY)" = "$(valeur_env "$ROOT/serviceIA/backend/.env" SERVICE_API_TOKEN)" ] ||
  alerte "AI_SERVICE_API_KEY (backend/.env) et SERVICE_API_TOKEN (serviceIA/backend/.env) diffèrent : le service IA refusera les analyses."
case "$(valeur_env "$ROOT/backend/.env" AI_SERVICE_BASE_URL)" in
  "http://127.0.0.1:$IA_PORT" | "http://localhost:$IA_PORT") ;;
  *) alerte "AI_SERVICE_BASE_URL (backend/.env) ne vise pas le serviceIA local (http://127.0.0.1:$IA_PORT)." ;;
esac
if [ "$IOS" = 1 ]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    alerte "Xcode introuvable : iOS ignoré."
    IOS=0
  elif ! xcrun simctl list devices 2>/dev/null | grep -q "$IOS_SIM"; then
    alerte "Simulateur $IOS_SIM introuvable (variable KORAI_IOS_SIM) : iOS ignoré."
    IOS=0
  fi
fi
if [ "$ANDROID" = 1 ]; then
  if [ ! -x "$ADB" ] || [ ! -x "$EMULATOR" ]; then
    alerte "SDK Android introuvable ($ANDROID_HOME) : Android ignoré."
    ANDROID=0
  elif ! "$EMULATOR" -list-avds 2>/dev/null | grep -qx "$AVD"; then
    alerte "Émulateur $AVD introuvable (variable KORAI_AVD) : Android ignoré."
    ANDROID=0
  fi
fi
LIBRE_GO=$(($(df -k "$HOME" | awk 'NR == 2 { print $4 }') / 1048576))
[ "$LIBRE_GO" -ge 10 ] || alerte "Seulement $LIBRE_GO Go libres : l'émulateur Android peut refuser de démarrer."
mkdir -p "$LOG_DIR"
ok "configuration vérifiée"

# ------------------------------------------------------------------ base de données
etape "Base de données"
if pg_pret; then
  ok "PostgreSQL répond (localhost:5432)"
else
  FORMULE=$(brew services list 2>/dev/null | awk '/^postgresql/ { print $1; exit }')
  [ -n "$FORMULE" ] || echec "PostgreSQL ne répond pas sur localhost:5432 et aucun service Homebrew n'est installé."
  info "démarrage de ${FORMULE}…"
  brew services start "$FORMULE" >/dev/null 2>&1 || echec "Impossible de démarrer PostgreSQL : brew services start $FORMULE"
  attendre 30 pg_pret || echec "PostgreSQL ne répond toujours pas."
  ok "PostgreSQL démarré ($FORMULE)"
fi

# ------------------------------------------------------------------ serveurs
lancer_serveur() { # lancer_serveur <nom> <port> <url de santé> <dossier> <commande…>
  local nom=$1 port=$2 sante=$3 dossier=$4
  shift 4
  if curl -fsS -m 2 "$sante" >/dev/null 2>&1; then
    if [ "$DETACHE" = 1 ]; then ok "$nom déjà lancé sur le port $port"; else ok "$nom déjà lancé sur le port $port (réutilisé : Ctrl-C ne l'arrêtera pas)"; fi
  elif port_occupe "$port"; then
    echec "Le port $port est pris par un autre programme, $nom ne peut pas démarrer (voir : lsof -nP -iTCP:$port)."
  else
    rm -f "$LOG_DIR/$nom.pid" # reste d'un serveur arrêté autrement que par arreter.sh
    lancer_en_fond "$LOG_DIR/$nom.log" "$dossier" "$@"
    LANCES="$LANCES $nom:$DERNIER_PID"
    ok "$nom en cours de démarrage (journal : logs/$nom.log)"
  fi
}

etape "Serveurs"
lancer_serveur serviceIA "$IA_PORT" "http://127.0.0.1:$IA_PORT/health" "$ROOT/serviceIA/backend" \
  .venv/bin/python -m uvicorn utils.rag_api:app --host 127.0.0.1 --port "$IA_PORT"
lancer_serveur backend "$BACKEND_PORT" "http://localhost:$BACKEND_PORT/health" "$ROOT/backend" npm run dev

# ------------------------------------------------------------------ appareils
if [ "$IOS" = 1 ] || [ "$ANDROID" = 1 ]; then etape "Appareils"; fi
if [ "$IOS" = 1 ]; then
  xcrun simctl boot "$IOS_SIM" >/dev/null 2>&1 # déjà démarré : sans effet
  open -a Simulator --args -CurrentDeviceUDID "$IOS_SIM"
  ok "simulateur iOS ouvert ($(xcrun simctl list devices | grep "$IOS_SIM" | sed -E 's/^ *//; s/ \(.*//'))"
fi
if [ "$ANDROID" = 1 ]; then
  if [ -n "$(android_serie)" ]; then
    ok "émulateur Android déjà lancé ($(android_serie))"
  else
    # -gpu host : le rendu logiciel figeait l'émulateur.
    lancer_en_fond "$LOG_DIR/emulateur-android.log" "$ROOT" \
      "$EMULATOR" -avd "$AVD" -gpu host -no-snapshot-load -no-snapshot-save -no-boot-anim
    ok "émulateur Android en cours de démarrage ($AVD, 30 à 60 s)"
  fi
fi

# ------------------------------------------------------------------ compilation
compiler() { # compiler <plateforme> <journal> <commande…>
  local plateforme=$1 journal=$2 debut=$SECONDS
  shift 2
  info "compilation ${plateforme}… (journal : logs/$journal)"
  if (cd "$ROOT/frontend" && "$@") >"$LOG_DIR/$journal" 2>&1; then
    ok "app $plateforme compilée en $((SECONDS - debut)) s"
  else
    alerte "compilation $plateforme échouée : voir logs/$journal"
    return 1
  fi
}

IOS_COMPILE=0 ANDROID_COMPILE=0
if [ "$BUILD" = 1 ] && { [ "$IOS" = 1 ] || [ "$ANDROID" = 1 ]; }; then
  etape "Compilation de l'app (les serveurs et les appareils démarrent pendant ce temps)"
  if [ "$IOS" = 1 ] && compiler iOS build-ios.log flutter build ios --simulator --debug; then IOS_COMPILE=1; fi
  if [ "$ANDROID" = 1 ] && compiler Android build-android.log flutter build apk --debug; then ANDROID_COMPILE=1; fi
fi

# ------------------------------------------------------------------ attente des serveurs
etape "Attente des serveurs"
if attendre 180 curl -fsS -m 2 "http://127.0.0.1:$IA_PORT/health"; then
  MODELE=$(curl -fsS -m 2 "http://127.0.0.1:$IA_PORT/health" |
    python3 -c 'import json, sys; print(json.load(sys.stdin).get("llm_model", "?"))' 2>/dev/null)
  ok "serviceIA prêt (modèle Mistral : ${MODELE:-?})"
else
  alerte "serviceIA ne répond pas : voir logs/serviceIA.log (les analyses IA échoueront)."
fi
attendre 90 curl -fsS -m 2 "http://localhost:$BACKEND_PORT/health" || echec "Le backend ne répond pas : voir logs/backend.log."
ok "backend prêt"

# ------------------------------------------------------------------ app sur les appareils
if [ "$IOS" = 1 ]; then
  etape "App sur le simulateur iOS"
  xcrun simctl bootstatus "$IOS_SIM" -b >/dev/null 2>&1
  if [ "$IOS_COMPILE" = 1 ]; then
    if xcrun simctl install "$IOS_SIM" "$IOS_APP" >/dev/null 2>&1; then ok "app installée"; else alerte "installation impossible"; fi
  fi
  if xcrun simctl get_app_container "$IOS_SIM" "$IOS_BUNDLE" >/dev/null 2>&1; then
    xcrun simctl terminate "$IOS_SIM" "$IOS_BUNDLE" >/dev/null 2>&1
    if xcrun simctl launch "$IOS_SIM" "$IOS_BUNDLE" >/dev/null 2>&1; then ok "app ouverte"; else alerte "impossible d'ouvrir l'app"; fi
  else
    alerte "app absente du simulateur : relancez sans --sans-build"
  fi
fi

if [ "$ANDROID" = 1 ]; then
  etape "App sur l'émulateur Android"
  info "attente de la fin du démarrage…"
  if ! attendre 240 android_demarre; then
    alerte "l'émulateur n'a pas fini de démarrer : voir logs/emulateur-android.log"
  else
    SERIE=$(android_serie)
    # Saisie du code affichée tout de suite : le code reste à taper dans la fenêtre de l'émulateur.
    android_deverrouille || reveiller_android
    # L'app appelle 127.0.0.1:4000 : sur l'émulateur, ce port doit être renvoyé vers le Mac.
    if "$ADB" -s "$SERIE" reverse tcp:$BACKEND_PORT tcp:$BACKEND_PORT >/dev/null 2>&1; then
      ok "port $BACKEND_PORT de l'émulateur relié au backend (adb reverse)"
    else
      alerte "adb reverse impossible : l'app ne joindra pas le backend"
    fi
    if [ "$ANDROID_COMPILE" = 1 ]; then
      if "$ADB" -s "$SERIE" install -r "$APK" >/dev/null 2>&1; then ok "app installée"; else alerte "installation impossible"; fi
    fi
    if ! android_deverrouille; then
      printf "  %s→ Déverrouillez l'émulateur Android en saisissant son code : l'app s'ouvrira ensuite (3 min au plus).%s\n" "$GRAS" "$FIN"
      if attendre 180 android_deverrouille_sinon_reveiller; then ok "émulateur déverrouillé"; else alerte "émulateur toujours verrouillé"; fi
    fi
    if ! android_deverrouille; then
      alerte "app non ouverte : déverrouillez l'émulateur puis ouvrez Korai (ou relancez ./demarrer.sh --sans-build)"
    elif "$ADB" -s "$SERIE" shell pm path "$ANDROID_PKG" 2>/dev/null | grep -q '^package:'; then
      "$ADB" -s "$SERIE" shell am force-stop "$ANDROID_PKG" >/dev/null 2>&1
      if "$ADB" -s "$SERIE" shell am start -n "$ANDROID_PKG/.MainActivity" >/dev/null 2>&1; then
        ok "app ouverte"
      else
        alerte "impossible d'ouvrir l'app"
      fi
    else
      alerte "app absente de l'émulateur : relancez sans --sans-build"
    fi
  fi
fi

# ------------------------------------------------------------------ résumé
etape "Korai est lancé"
info "Backend : http://localhost:$BACKEND_PORT · service IA : http://127.0.0.1:$IA_PORT/docs"
info "Comptes de démonstration : nurse, orl, admin ou patient @korai.local (mot de passe : backend/src/common/seed.ts)"
if [ "$IOS" = 1 ]; then info "Face ID sur le simulateur : notifyutil -p com.apple.BiometricKit_Sim.pearl.match"; fi
if [ "$ANDROID" = 1 ]; then info "Empreinte sur l'émulateur : \"\$ANDROID_HOME/platform-tools/adb\" -e emu finger touch 1"; fi
info "Journaux : logs/"

if [ "$DETACHE" = 1 ]; then
  # Les serveurs lancés ici survivent au script : leur PID est noté pour ./arreter.sh.
  for entree in $LANCES; do printf '%s\n' "${entree##*:}" >"$LOG_DIR/${entree%%:*}.pid"; done
  LANCES=""
  info "Backend et serviceIA tournent en arrière-plan : ./arreter.sh pour les arrêter."
elif [ -n "$LANCES" ]; then
  JOURNAUX=""
  for entree in $LANCES; do JOURNAUX="$JOURNAUX $LOG_DIR/${entree%%:*}.log"; done
  printf '\n%sJournaux des serveurs ci-dessous. Ctrl-C arrête les serveurs (les émulateurs restent ouverts).%s\n\n' "$GRAS" "$FIN"
  # shellcheck disable=SC2086 # une entrée par journal
  tail -n 3 -f $JOURNAUX
else
  info "Serveurs lancés avant ce script : ils continuent de tourner."
fi
