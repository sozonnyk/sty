require_relative 'util'

module Sty
  class Proxy
    include Sty::Util

    def config
      @config = @config || yaml('proxy')
    end

    def proxy_vars
      ENV.select { |e| e =~ /(https?|no)_proxy/i }
    end

    def unset
      proxy_vars.keys.map do |e|
        "unset #{e}"
      end
    end

    def set(px)
      proxy = config[px]

      unless proxy
        STDERR.puts red("ERROR! Proxy #{px} was not found in the config file.")
        exit 1
      end

      STDERR.puts "Proxy is set to #{proxy['proxy']}"
      ["export http_proxy=#{proxy['proxy']}",
       "export https_proxy=#{proxy['proxy']}",
       "export no_proxy=#{proxy['no-proxy']}"]
    end

    def output(strings)
      puts "#EVAL#"
      strings.each do |s|
        puts "#{s};"
      end
    end

    def action(px)
      case
      when px.nil?
        STDERR.puts "Current proxy vars:"
        proxy_vars.each do |k, v|
          STDERR.puts "#{k}=#{v}"
        end
      when px =~ /off/i
        STDERR.puts "Proxy vars unset"
        output(unset)
      else
        output(unset + set(px))
      end
    end

  end
end