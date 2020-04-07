#!/bin/sh

# Start redis service
redis-server --appendonly yes --maxmemory 5M &

# Start dnsmasq once so that third party black lists can be downloaded
# After rules are built dnsmasq will be restarted
# This also helps resolve any proxy server domain names while booting up dnscrypt
dnsmasq --conf-file=/etc/dnsmasq.conf

# Start nodejs web interface
node /shared/server.js &

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

while :
do
  if redis-cli exists keep:notracking | grep -q 0; then

    # Get the latest copy of the block lists
    if [ -f /shared/hosts-blocklists/hostnames.txt ]; then
      git -C /shared/hosts-blocklists pull
    else
      git clone --depth=1 https://github.com/notracking/hosts-blocklists /shared/hosts-blocklists
    fi

    # Copy block list files to location for usage
    cp -fv /shared/hosts-blocklists/domains.txt /etc/dnsmasq.d/notracking.conf
    cp -fv /shared/hosts-blocklists/hostnames.txt /shared/hosts/notracking.txt

    # Make sure that dnsmasq gets restarted
    redis-cli del keep:rules

    # Set the timeout flag
    redis-cli setex keep:notracking 86400 1

  fi

  if redis-cli exists keep:rules | grep -q 0; then

    # Delete current contents
    rm -fv /shared/rules/00_dynamic.yaml

    # Build the dynamic allow list
    if redis-cli exists rules:allow | grep -q 1; then
      { \
        echo "allow:" \
        && redis-cli smembers rules:allow | xargs -I{} echo '  -' {} \
      ;} >> /shared/rules/00_dynamic.yaml
    fi

    # Build the dynamic block list
    if redis-cli exists rules:block | grep -q 1; then
      { \
        echo "block:" \
        && redis-cli smembers rules:block | xargs -I{} echo '  -' {} \
      ;} >> /shared/rules/00_dynamic.yaml
    fi

    # Build the dynamic hosts list
    if redis-cli exists rules:hosts | grep -q 1; then
      { \
        echo "hosts:" \
        && redis-cli smembers rules:hosts | xargs -I{} echo '  -' {} \
      ;} >> /shared/rules/00_dynamic.yaml
    fi

    # Rebuild the rule set yaml files
    2>&1 ruby /shared/rules.rb `redis-cli get mode:last`

    # Kill the dnsmasq process
    pkill dnsmasq

    # Start dnsmasq in daemon mode
    dnsmasq --conf-file=/etc/dnsmasq.conf

    # Set the timeout flag
    redis-cli set keep:rules `date -u -Iseconds | sed 's|UTC|Z|'`

  fi

  sleep 1
done