#!/bin/bash
# Copyright 2026 Wings8 Technology.
# Active / desactive le Turbo Boost du processeur (intel_pstate + cpufreq
# boost generique), avec persistance de l etat (re-applique au demarrage).
#
# Usage : cpu_turbo.sh on | off | apply | status

set -u

STATE_DIR="/var/lib/wings8os"
STATE_FILE="${STATE_DIR}/cpu_turbo.state"
PSTATE_NODE="/sys/devices/system/cpu/intel_pstate/no_turbo"
BOOST_NODE="/sys/devices/system/cpu/cpufreq/boost"

write_turbo() {
  local state="$1"
  local wrote=0
  local rc=0
  if [ -w "$PSTATE_NODE" ]; then
    wrote=1
    if [ "$state" -eq 1 ]; then echo 0 > "$PSTATE_NODE" || rc=1
    else echo 1 > "$PSTATE_NODE" || rc=1; fi
  fi
  if [ -w "$BOOST_NODE" ]; then
    wrote=1
    echo "$state" > "$BOOST_NODE" || rc=1
  fi
  if [ "$wrote" -eq 0 ]; then
    echo "cpu_turbo: aucun noeud turbo accessible (support boost absent du noyau)" >&2
    return 2
  fi
  return "$rc"
}

read_state() {
  local v
  v=$(cat "$STATE_FILE" 2>/dev/null || echo "")
  case "$v" in 0|1) echo "$v"; return ;; esac
  echo 1
}

current_effective() {
  local nt b
  if [ -r "$PSTATE_NODE" ]; then
    nt=$(cat "$PSTATE_NODE" 2>/dev/null || echo "")
    [ "$nt" = "0" ] && { echo "on"; return; }
    [ "$nt" = "1" ] && { echo "off"; return; }
  fi
  if [ -r "$BOOST_NODE" ]; then
    b=$(cat "$BOOST_NODE" 2>/dev/null || echo "")
    [ "$b" = "1" ] && { echo "on"; return; }
    [ "$b" = "0" ] && { echo "off"; return; }
  fi
  echo "unknown"
}

case "${1:-}" in
  on)
    write_turbo 1 || exit 1
    mkdir -p "$STATE_DIR"
    echo 1 > "$STATE_FILE"
    echo "cpu_turbo: turbo active"
    ;;
  off)
    write_turbo 0 || exit 1
    mkdir -p "$STATE_DIR"
    echo 0 > "$STATE_FILE"
    echo "cpu_turbo: turbo desactive"
    ;;
  apply)
    state=$(read_state)
    write_turbo "$state" || exit 1
    ;;
  status)
    current_effective
    ;;
  *)
    echo "Usage: $0 {on|off|apply|status}" >&2
    exit 64
    ;;
esac