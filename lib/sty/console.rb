require_relative 'util'

require 'cgi'
require 'json'
require 'net/http'
require 'open3'

module Sty
  class Console
    include Sty::Util

    CONSOLE_URL = 'https://ap-southeast-2.console.aws.amazon.com/'
    SIGN_IN_URL = 'https://signin.aws.amazon.com/federation'
    SIGN_OUT_URL = 'https://ap-southeast-2.console.aws.amazon.com/console/logout!doLogout'

    SESSION_DURATION_SECONDS = 43200

    BROWSERS = %w(chrome firefox vivaldi safari)

    def go(url, browser = '', incognito = false)
      url = "'#{url}'"
      run = %w(open)
      run << '-n' if incognito
      case browser.downcase
      when 'safari'
        run << "-a 'Safari'"
        run << url
      when 'chrome'
        run << "-a 'Google Chrome'"
        incognito ? run << "--args --incognito #{url}" : run << url
      when 'firefox'
        run << '-a Firefox'
        incognito ? run << "--args -private-window #{url}" : run << url
      when 'vivaldi'
        run << '-a Vivaldi'
        incognito ? run << "--args --incognito #{url}" : run << url
      else
        run << url
      end

      puts run.join(' ')
      system(run.join(' '))
    end

    def signin_params
      return @signin_params if @signin_params

      creds_string = {'sessionId' => ENV['AWS_ACCESS_KEY_ID'],
                      'sessionKey' => ENV['AWS_SECRET_ACCESS_KEY'],
                      'sessionToken' => ENV['AWS_SESSION_TOKEN']}.to_json

      uri = URI(SIGN_IN_URL)
      params = {'Action' => 'getSigninToken',
                'Session' => creds_string}
      uri.query = URI.encode_www_form(params)

      begin
        res = Net::HTTP.get_response(uri)
      rescue Exception => e
        puts red("ERROR! Unable to obtain signin token.")
        puts white(e.message)
        exit 1
      end

      unless res.is_a?(Net::HTTPSuccess)
        puts red("ERROR! Unable to obtain signin token.")
        puts white("#{SIGN_IN_URL} returns #{res.code}")
        puts res.body
        exit 1
      end

      @signin_params = JSON.parse(res.body)
    end

    def action(browser, incognito, logout)
      if logout
        logout(browser, incognito)
      else
        login(browser, incognito)
      end
    end

    def logout(browser, incognito)
      go(SIGN_OUT_URL, browser || '', incognito)
    end

    def login(browser, incognito)
      act_acc

      if remained_minutes <= 0
        puts red("Session expired")
        exit 1
      end

      signin_params['Action'] = 'login'
      signin_params['Destination'] = CONSOLE_URL

      params_str = signin_params.map do |k, v|
        "#{k}=#{CGI.escape(v.to_s)}"
      end.join('&')

      console_url = "#{SIGN_IN_URL}?#{params_str}"

      go(console_url, browser || '', incognito)
    end


  end
end