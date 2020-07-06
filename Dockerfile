FROM node:13-alpine

ENV TERM xterm-256color

# Install pre-requisites
RUN apk add --update --no-cache dnscrypt-proxy ruby dnsmasq redis ncurses git \
 && rm -rfv /var/cache/apk/*

# Modify the dnsmasq config file
RUN {  echo "user=root" \
    && echo "no-resolv" \
    && echo "no-poll" \
    && echo "no-hosts" \
    && echo "cache-size=1000" \
    && echo "filterwin2k" \
    && echo "port=5353" \
    && echo "log-queries" \
    && echo "server=127.0.0.1#53" \
    && echo "addn-hosts=/shared/hosts" \
    && echo "log-facility=/dev/stderr" \
    ;} >> /etc/dnsmasq.conf

# Modify the dnscrypt-proxy config file
ARG toml=/etc/dnscrypt-proxy/dnscrypt-proxy.toml
RUN cat $toml | \
    sed -e 's|# log_level = .*|log_level = 0|' | \
    sed -e 's|ipv6_servers = .*|ipv6_servers = true|' | \
    sed -e 's|require_dnssec = .*|require_dnssec = true|' | \
    sed -e 's|listen_addresses = .*|listen_addresses = ["127.0.0.1:53"]|' | \
    sed -e 's|# server_names = .*|server_names = ["cloudflare", "cloudflare-ip6"]|' \
    > $toml.new \
 && mv -fv $toml.new $toml

RUN mkdir -p /shared/hosts

RUN cd /shared && yarn add express nunjucks redis jquery node-time-ago

COPY favicon.ico /shared/
COPY entrypoint.sh /shared/
COPY rules.rb /shared/
COPY index.html /shared/
COPY server.js /shared/

COPY visigoth.sh /usr/local/bin/visigoth
RUN chmod +x /usr/local/bin/visigoth
CMD [ "node", "server.js" ]

ENTRYPOINT sh /shared/entrypoint.sh