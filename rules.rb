require 'yaml'
require 'redis'

mode = ARGV[0]
path = "/shared/rules/"
rules = []
redis = Redis.new
allow = redis.smembers('rules:allow')
block = redis.smembers('rules:block')
hosts = redis.smembers('rules:hosts')
raw = redis.smembers('rules:raw')

Dir.new(path).sort.each do |item|
  next if mode == 'off'

  next if item == '.' or item == '..'

  next if not item.end_with? ".yaml" and not item.end_with? ".yml"

  puts "processing rule file: " + item

  yaml = YAML::load(File.read(path + item))

  if yaml.has_key?('allow')
    yaml['allow'].each do |item|
      allow.push(item)
    end
  end

  if yaml.has_key?('raw')
    yaml['raw'].each do |item|
      raw.push(item)
    end
  end

  if yaml.has_key?('block')
    yaml['block'].each do |item|
      block.push(item)
    end
  end
  
  if yaml.has_key?('hosts')
    yaml['hosts'].each do |item|
      hosts.push(item)
    end
  end
end

allow.each do |item|
  if not (mode == 'paranoid' and not item.include? ".")
    rules.push("server=/.#{item}/127.0.0.1#53")
    rules.push("server=/.#{item}/::1#53")
  end
end

block.each do |item|
  rules.push("address=/.#{item}/0.0.0.0")
  rules.push("address=/.#{item}/::")
end

raw.each do |item|
  rules.push(item)
end

# When in strict modes (tight/paranoid) use wildcard to deny any non-allowed route
if not mode == "loose" and not mode == 'off'
  rules.push("address=/#/0.0.0.0")
  rules.push("address=/#/::")
end

File.write('/etc/dnsmasq.d/rules.conf', rules.join("\n"))
File.write('/shared/hosts/hosts.txt', hosts.join("\n"))