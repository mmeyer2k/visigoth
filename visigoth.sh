#!/bin/sh

CMD=${1:-help}

function greenline(){
  tput setaf 2
  echo "$1"
  tput sgr0
}

function redline(){
  tput setaf 1
  echo "$1"
  tput sgr0
}

function underline(){
  tput smul
  echo "$1"
  tput rmul
}

function dnsmasqWait(){
  greenline "Restarting dns server..."
  1>/dev/null redis-cli del keep:rules
  while true; do
    if redis-cli exists keep:rules | grep -q 1 > /dev/null; then
      break
    fi
    sleep 0.1
  done
}

if [[ ${CMD} == "reload" || ${CMD} == "-r" ]]; then

  MODE=${2:-"tight"}

  if [[ ${MODE} != "off" && ${MODE} != "tight" && ${MODE} != "loose" && ${MODE} != "paranoid" ]]; then
    redline "Rule mode [${MODE}] is not valid"
    exit 1
  fi

  greenline "Rebuilding rulesets in mode: `tput smul`${MODE}`tput rmul`"
  ruby /shared/rules.rb
  1>/dev/null redis-cli set mode:last $MODE
  dnsmasqWait
  greenline "Done!"

elif [[ ${CMD} == "drop" || ${CMD} == "-d" ]]; then

  1>/dev/null redis-cli del rules:allow rules:block
  dnsmasqWait

elif [[ ${CMD} == "update" || ${CMD} == "-u" ]]; then

  greenline "Updating block lists from https://github.com/notracking/hosts-blocklists"
  1>/dev/null redis-cli del keep:notracking

elif [[ ${CMD} == "-a" || ${CMD} == "allow" || ${CMD} == "-b" || ${CMD} == "block" ]]; then

  [[ ${CMD} == "-a" || ${CMD} == "allow" ]] && LIST="allow" || LIST="block"
  if [[ ${2} == '-r' || ${2} == 'remove' ]]; then
    DOMAIN=${3}
    greenline "Removed ${DOMAIN} from the ${LIST} list!"
    1>/dev/null redis-cli srem rules:${LIST} ${DOMAIN}
  else
    DOMAIN=${2}
    greenline "Added ${DOMAIN} to the ${LIST} list!"
    1>/dev/null redis-cli sadd rules:${LIST} ${DOMAIN}
  fi
  dnsmasqWait

elif [[ ${CMD} == "--help" || ${CMD} == "help" || ${CMD} == "-h" ]]; then

  MODE=`redis-cli get mode:last`
  greenline '      .__       .__               __  .__     '
  greenline '___  _|__| _____|__| ____   _____/  |_|  |__  '
  greenline '\  \/ /  |/  ___/  |/ ___\ /  _ \   __\  |  \ '
  greenline ' \   /|  |\___ \|  / /_/  >  <_> )  | |   Y  \'
  greenline '  \_/ |__/____  >__\___  / \____/|__| |___|  /'
  greenline '              \/  /_____/                  \/ '
  echo
  echo Current rule enforcement mode: `tput smul`$MODE`tput rmul`
  echo
  underline "Command usage"
  echo "    -r|reload [mode]  Rebuild rulesets and restart dnsmasq"
  echo "    -u|update         Update thirdparty block lists"
  echo "    -h|help           Display help dialog"
  echo
  underline "Manage dynamic rule entries"
  echo "    -a|allow [-r|remove] domain   Add domain to the allow list (add -r to remove)"
  echo "    -b|block [-r|remove] domain   Add domain to the block list (add -r to remove)"
  echo "    -h|hosts [-r|remove] ip host  Add domain and ip to the hosts list (add -r to remove)"
  echo "    -s|save                       Dumps current dynamic rules as config yaml to stdout"
  echo "    -d|drop                       Drops all dynamic rules"

else

  echo "Command not found: [${CMD}]. Please use -h to view options."

fi