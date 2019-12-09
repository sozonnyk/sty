require 'thor'
require_relative 'info'
require_relative 'auth'
require_relative 'console'
require_relative 'proxy'
require_relative 'ssh'
require_relative 'ssm'

class Cli < Thor
  map auth: :login, acct: :account, px: :proxy

  def self.basename
    'sty'
  end

  desc "ssm [OPTIONS] <SEARCH_TERMS...>","Creates ssm session to an EC2 instance. SEARCH_TERMS to search in EC2 instance ID, name or IP address"
  def ssm(*search_term)
    Ssm.new.connect(search_term)
  end

  desc "ssh [OPTIONS] <SEARCH_TERMS...>","Creates ssh connection to an EC2 instance through existing jumphost. SEARCH_TERMS to search in EC2 instance ID, name or IP address"
  method_option :no_jumphost, type: :boolean, default: false, aliases: "-n", desc: "Connect directly without jumphost"
  method_option :select_jumphost, type: :boolean, aliases: "-s", desc: "Select jumphost instance"
  method_option :use_key, type: :boolean, aliases: "-k", desc: "Use private key auth for target instance. Keys are searched recursively in ~/.sty/keys"
  def ssh(*search_term)
    Ssh.new.connect(search_term, options[:no_jumphost], options[:select_jumphost], options[:use_key])
  end

  desc "console", "Opens AWS console in browser for currently authenticated session"
  method_option :browser, type: :string, aliases: "-b", enum: Console::BROWSERS, desc: "Use specific browser"
  method_option :incognito, type: :boolean, aliases: "-i", desc: "Create new incognito window"
  method_option :logout, type: :boolean, aliases: "-l", dssc: "Logout from current session"
  def console
    Console.new.action(options[:browser], options[:incognito], options[:logout])
  end

  desc "login ACCOUNT_PATH", "Authenticate to the account"
  method_option :role, aliases: "-r", dssc: "Override role name"
  def login(path)
    source_run(__method__)
    Auth.new.login(path, options[:role])
  end

  desc "logout", "Forget current credentials and clear cache"
  def logout
    source_run(__method__)
    Auth.new.logout
  end

  desc "info", "Get current session information"
  def info
    Info.new.session_info
  end

  desc "account ACCOUNT_ID", "Find account information"
  def account(path)
    Info.new.account_info(path)
  end

  desc "proxy [PROXY_ID]", "Switch session proxy (use 'off' to disable)"
  def proxy(px = nil)
    source_run(__method__)
    Proxy.new.action(px)
  end

  no_tasks do
    def source_run(method)
      unless ENV['STY_SOURCE_RUN'] == 'true'
        puts "When using '#{method.to_s}' command, you must source it, i.e.: '. sty #{method.to_s}'"
        exit 128
      end
    end
  end

end

Cli.start(ARGV)