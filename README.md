# Visigoth

A highly customizable, security-focused DNS server stack for Docker.

- Uses DNSCrypt to provide secure delivery of DNS packets
- Uses Dnsmasq to allow for granular rule sets
- Improves security by using reputable third-party backlists
- Supports several build modes for easily switching between security levels
- Commandline interface for interacting with container
- Nodejs web interface to quickly update rules

## Getting Started

Let's get a DNS server with sensible default values started.

### With docker

```bash
docker run --name visigoth --restart always -p 127.0.0.1:4242:4242 -p 127.0.0.1:53:5353 -v ./rules:/shared/rules -d mmeyer2k/visigoth
```

### With docker-compose

Add visigoth DNS server to your stack with this docker-compose yaml configuration.

```yaml
services:
  visigoth:
    container-name: visigoth
    image: mmeyer2k/visigoth
    restart: always
    ports:
      - 127.0.0.1:53:5353/udp
      - 127.0.0.1:4242:4242/udp
    volumes:
      - ./rules:/shared/rules
```

### Using the container

If everything went well, you now have a secure DNS tunnel running on `127.0.0.1`!
Configure your system to send DNS queries to `127.0.0.1` and `::1`.

## Commandline client

To help the user quickly manipulate container options, a robust command line client is provided.

```
docker exec -t visigoth visigoth
```

Since you will be interacting with visigoth frequently in real-world usage, setting a bash alias can save time and keystrokes.
To do this, add an entry like the following to your `~/.bashrc` file.

```
alias visi='docker exec -t visigoth visigoth'
```

## Configuration

### Rules

DNS routing rules are simply formatted yaml files which are used to generate configurations for Dnsmasq.
These files should be stored in a folder which will be mapped to the container's `/shared/rules` directory.

It is important to understand how Dnsmasq handles rule precedence to fully harness the flexibility of visigoth.
More specific rules anyways supersede less specific rules.

This example demonstrates a typical usage case. 
The TLD `.info` is completely blacklisted, but `dnscrypt.info` and `example.info` will still resolve.

Each root key (i.e. "allow:" or "block") can only be used once per yaml file.

```yaml
block:
  - info
allow:
  - dnscrypt.info
  - example.info
```

Add hosts mappings between domain(s) and an IP.

```yaml
hosts:
  - 44.55.44.55 example.org example.com
  - 11.22.33.44 example.net
```

### Ruleset modes

By default, the build script will compile the dns rule sets in `tight` mode.
To rebuild the visigoth container, simply run `build.sh` with a second parameter.

```bash
visi -r [mode]
```

| Ruleset Mode | Description |
| ------------ | ----------- |
| `off`        | No DNS rules are compiled. |
| `loose`      | Only blacklisted DNS entries are denied. |
| `tight`      | Only whitelisted DNS entries are forwarded. |
| `paranoid`   | Same as `tight` except no TLD whitelists are respected. |
