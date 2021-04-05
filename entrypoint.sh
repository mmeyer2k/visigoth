#!/bin/sh

# Start redis service
redis-server --appendonly yes --maxmemory 5M &

# Start dnsmasq once so that third party black lists can be downloaded
# After rules are built dnsmasq will be restarted
# This also helps resolve any proxy server domain names while booting up dnscrypt
dnsmasq --conf-file=/etc/dnsmasq.conf

# Start nodejs web interface and redirect stdout to stderr
node /shared/server.js & 1>&2

# Modify dnscrypt settings from runtime ENV variables
TOML=/etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed -i "s|fallback_resolver = .*|fallback_resolver = '${FALLBACK_RESOLVER:-9.9.9.9}:53'|" $TOML
if [ "${PROXY}" != "" ]; then
  sed -i "s|# proxy = .*|proxy = '${PROXY}'|" $TOML;
  sed -i "s|proxy = .*|proxy = '${PROXY}'|" $TOML;
else
  sed -i "s|proxy = .*|# proxy = '${PROXY}'|" $TOML;
fi

# Start dnscrypt service and pass to background
dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml start &

# Set the default mode value into redis memory
redis-cli setnx mode:last ${MODE:-tight}

# Set the default notracking option
redis-cli setnx notrack ${NOTRACK:-on}

# Block until dnsmasq has started
while ! nc -z localhost 5353; do
  sleep 0.1;
done

# Block until dnscrypt has started
while ! nc -z localhost 53; do
  sleep 0.1;
done

# Block until redis container has started
while ! redis-cli ping; do
  sleep 0.1
done

# Begin the controlling loop
while :
do
  # If the tracking lists have not been downloaded or are expired...
  if redis-cli exists keep:notracking | grep -q 0; then

    # Pull in latest changes to global block lists
    git -C /shared/hosts-blocklists pull

    # Copy block list files to location for usage
    cp -fv /shared/hosts-blocklists/domains.txt /etc/dnsmasq.d/notracking.conf
    cp -fv /shared/hosts-blocklists/hostnames.txt /shared/hosts/notracking.txt

    # Make sure that dnsmasq gets restarted at the end of main loop
    redis-cli del keep:rules

    # Set the timeout flag
    redis-cli setex keep:notracking 86400 1

    # Store last commit hash for linking to github
    redis-cli set notracking:hash `git -C /shared/hosts-blocklists rev-parse --verify HEAD`

  fi

  # If the one hour off timer is up...
  if redis-cli exists mode:next | grep -q 1; then
    if redis-cli exists mode:time | grep -q 0; then
      redis-cli rename mode:next mode:last
      redis-cli del keep:rules
    fi
  fi

  # If the ruleset has been triggered to be rebuilt...
  if redis-cli exists keep:rules | grep -q 0; then

    # Rebuild the rule set yaml files
    2>&1 ruby /shared/rules.rb `redis-cli get mode:last`

    # Kill the dnsmasq process
    pkill dnsmasq

    # Start dnsmasq in daemon mode
    dnsmasq --conf-file=/etc/dnsmasq.conf

    # Set the timeout flag
    redis-cli set keep:rules `date -u -Iseconds | sed 's|UTC|Z|'`

  fi

  sleep 2
done