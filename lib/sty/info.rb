require_relative 'util'

module Sty
  class Info
    include Sty::Util

    def session_info
      if ENV['AWS_ACTIVE_ACCOUNT']
        puts "Active account: #{white(ENV['AWS_ACTIVE_ACCOUNT'])}"
      else
        puts red("You are not authenticated with sty")
      end

      if ENV['AWS_ACTIVE_IDENTITY']
        puts "Active identity: #{white(ENV['AWS_ACTIVE_IDENTITY'])}"
      end

      if ENV['AWS_SESSION_EXPIRY']
        if remained_minutes > 0
          puts "Session active, expires in #{white(remained_minutes)} min."
        else
          puts red("Session expired")
        end
      end

    end

    def account_info(partial)

      config = yaml('auth')

      puts "Searching config for '#{partial}':"
      result = deep_find(config, partial)

      if result.any?
        result.each do |k, v|
          puts "#{k}: #{v}"
        end
      else
        puts 'Nothing found'
      end
    end

  end
end