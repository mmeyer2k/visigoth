require 'yaml'

mode = ARGV[0]

path = "/shared/rules/"
rules = []
hosts = []

Dir.new(path).sort.each do |item|
  next if item == '.' or item == '..'

  next if mode == 'off'

  next if not item.end_with? ".yaml" and not item.end_with? ".yml"

  yaml = YAML::load(File.read(path + item))

  if yaml.has_key?('allow')
    yaml['allow'].each do |allow|
      if allow.strip
        if not (mode == 'paranoid' and not allow.include? ".")
          rules.push("server=/.#{allow}/127.0.0.1#53")
          rules.push("server=/.#{allow}/::1#53")
        end
      end
    end
  end

  if yaml.has_key?('raw')
    yaml['raw'].each do |raw|
      if raw.strip
        rules.push(raw)
      end
    end
  end

  if yaml.has_key?('block')
    yaml['block'].each do |block|
      if block.strip
        rules.push("address=/.#{block}/0.0.0.0")
        rules.push("address=/.#{block}/::")
      end
    end
  end
  
  if yaml.has_key?('hosts')
    yaml['hosts'].each do |host|
      if host.strip
        hosts.push(host)
      end
    end
  end

  puts "processed rule file: " + item
end

if not mode == "loose" and not mode == 'off'
  rules.push("address=/#/0.0.0.0")
  rules.push("address=/#/::")
end

File.write('/etc/dnsmasq.d/rules.conf', rules.join("\n"))
File.write('/shared/hosts/hosts.txt', hosts.join("\n"))