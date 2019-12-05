require_relative 'functions'
require 'psych'

@dir = File.expand_path(File.dirname(__FILE__)+'/..')
@config = Psych.load_file("#{@dir}/px.yaml")

def unset
  ENV.select { |e| e =~ /(https?|no)_proxy/i }.keys.map do |e|
    "unset #{e}"
  end
end

def set(px)
  proxy = @config[px]

  unless proxy
    STDERR.puts red("ERROR! Proxy #{px} not found in config file.")
    exit 1
  end

  STDERR.puts "Proxy is set to #{proxy['proxy']}"
  ["export http_proxy=#{proxy['proxy']}",
   "export https_proxy=#{proxy['proxy']}",
   "export no_proxy=#{proxy['no-proxy']}"]
end

def output(strings)
  strings.each do |s|
    puts "#{s};"
  end
end

px = ARGV[0]

if px =~ /off/i
  output(unset)
else
  output(unset + set(px))
end