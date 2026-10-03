#!/usr/bin/env bash
# Arrête le backend et serviceIA lancés en arrière-plan par demarrer-ios.sh, demarrer-android.sh
# ou demarrer.sh --detache. Les émulateurs et PostgreSQL restent ouverts.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$ROOT/logs"

if [ -t 1 ]; then
  VERT=$'\033[32m' JAUNE=$'\033[33m' PALE=$'\033[2m' FIN=$'\033[0m'
else
  VERT='' JAUNE='' PALE='' FIN=''
fi
ok() { printf '  %s✓%s %s\n' "$VERT" "$FIN" "$1"; }
info() { printf '  %s%s%s\n' "$PALE" "$1" "$FIN"; }
alerte() { printf '  %s!%s %s\n' "$JAUNE" "$FIN" "$1"; }

# Le PID noté est le chef du groupe du serveur (npm → tsx → node, uvicorn) : le groupe doit
# encore exister et contenir le bon programme (un PID peut avoir été réattribué depuis).
groupe_actif() { # groupe_actif <pid> <motif de la commande>
  ps -A -o pgid=,command= 2>/dev/null | awk -v g="$1" '$1 == g' | grep -Eq -- "$2"
}

arreter() { # arreter <nom> <motif de la commande> <port>
  local nom=$1 motif=$2 port=$3 fichier="$LOG_DIR/$1.pid" pid
  if [ -f "$fichier" ]; then
    pid=$(tr -dc '0-9' <"$fichier")
    if [ -n "$pid" ] && groupe_actif "$pid" "$motif"; then
      kill -TERM -- "-$pid" 2>/dev/null
      for _ in 1 2 3 4 5 6 7 8 9 10; do # jusqu'à 5 s pour s'arrêter proprement
        groupe_actif "$pid" "$motif" || break
        sleep 0.5
      done
      kill -KILL -- "-$pid" 2>/dev/null
      ok "$nom arrêté"
    else
      info "$nom : déjà arrêté"
    fi
    rm -f "$fichier"
  fi
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    alerte "$nom tourne encore sur le port $port, lancé ailleurs (demarrer.sh au premier plan ou un terminal) : arrêtez-le là (Ctrl-C)."
  elif [ ! -f "$fichier" ] && [ -z "${pid:-}" ]; then
    info "$nom : aucun serveur en marche"
  fi
}

printf 'Arrêt des serveurs Korai\n'
arreter serviceIA 'utils.rag_api' 8000
arreter backend 'run dev|src/server' 4000
