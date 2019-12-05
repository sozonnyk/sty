require 'psych'
require 'time'

def colorize(string, color_code)
  "\e[#{color_code}m#{string}\e[0m"
end

def red(string)
  colorize(string, 31)
end

def green(string)
  colorize(string, 32)
end

def yellow(string)
  colorize(string, 33)
end

def magenta(string)
  colorize(string, 35)
end

def white(string)
  colorize(string, 97)
end

def to_path(fqn)
  [fqn].flatten.map { |a| a.split("/") }.flatten
end

def to_fqn(path)
  path.join('/')
end

def dir
  @dir = @dir || File.expand_path(File.dirname(__FILE__)+'/../..')
end

def cache_file(path, identity)
  "#{dir}/auth-cache/#{path.join('-')}-#{identity}.yaml"
end

def yaml(file)
  Psych.load_file("#{dir}/#{file}.yaml")
end

def dump(hash, file)
  File.open("#{dir}/#{file}.yaml", 'w') do |f|
    f.write(Psych.dump(hash))
  end
end

def remained_minutes
  ((Time.parse(ENV['AWS_SESSION_EXPIRY']) - Time.now) / 60).to_i
end

def region
  ENV['AWS_REGION'] || DEFAULT_REGION
end

def act_acc
  act_acc = ENV['AWS_ACTIVE_ACCOUNT']
  unless act_acc
    puts red('ERROR! AWS_ACTIVE_ACCOUNT variable is not set. Is your session authenticated ?')
    exit 1
  end
  act_acc
end

def matches(container, value)
  container = container.to_s
  if /#{value}/i =~ container.to_s
    match = $&
    container.split(match).insert(1,white(match)).join
  end
end

def deep_find(obj, value, result = {}, path = [])
  if obj.is_a?(Hash)
    obj.each do |k,v|
      deep_find(v, value, result, path + [k])
    end
    return result
  else
    m = matches(obj, value)
    result[to_fqn(path)] = m if m
  end
end
