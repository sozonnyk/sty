require 'psych'
require 'time'

module Sty
  module Util

    def sty_home
      home = File.expand_path('~')
      "#{home}/.sty"
    end

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

    def deep_merge(h1, h2)
      h1.merge(h2) { |k, v1, v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? deep_merge(v1, v2) : v2 || v1 }
    end

    def dir
      @dir = @dir || sty_home
    end

    def yaml(file)
      Psych.load_file("#{dir}/#{file}.yaml")
    end

    def group_yaml(glob)
      Dir.glob("#{dir}/#{glob}.yaml").reduce({}) do |memo, y|
        deep_merge(memo, Psych.load_file(y))
      end
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
      ENV['AWS_REGION'] || ENV['AWS_DEFAULT_REGION'] || DEFAULT_REGION
    end

    def set_aws_proxy
      Aws.config.update(http_proxy: ENV['https_proxy'])
    end

    def check_proxy
      unless ENV.find { |k, v| k =~ /HTTPS_PROXY/i }
        STDERR.puts red("WARNING! \"https_proxy\" env variable is not set.")
      end
    end

    def act_acc
      act_acc = ENV['AWS_ACTIVE_ACCOUNT']
      unless act_acc
        puts red('ERROR! AWS_ACTIVE_ACCOUNT variable is not set. Is your session authenticated with Sty?')
        exit 1
      end
      act_acc
    end

    def matches(container, value)
      container = container.to_s
      if /#{value}/i =~ container.to_s
        match = $&
        container.split(match).insert(1, white(match)).join
      end
    end

    def deep_find(obj, value, result = {}, path = [])
      if obj.is_a?(Hash)
        obj.each do |k, v|
          deep_find(v, value, result, path + [k])
        end
        return result
      else
        m = matches(obj, value)
        result[to_fqn(path)] = m if m
      end
    end

  end
end
