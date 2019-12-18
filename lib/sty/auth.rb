require 'ostruct'
require_relative 'util'
require_relative 'dig'
require_relative 'credentials/credentials_store'

module Sty
  class Auth
    include Sty::Util

    SESSION_DURATION_SECONDS = 43_200
    DEFAULT_ROLE_NAME = 'ReadOnlyRole'
    DEFAULT_REGION = 'ap-southeast-2'

    def login(fqn, role = nil)
      check_proxy
      acc = account(fqn)
      if acc.parent
        creds = login_role(acc, role)
      else
        creds = login_bare(acc)
      end
      print_creds(acc, creds) if creds
    end

    def logout
      current = ENV['AWS_ACTIVE_ACCOUNT']
      identity = ENV['AWS_ACTIVE_IDENTITY']
      STDERR.puts "Logging off from: #{white(current)}"
      @cred_store.delete_creds(to_path(current), identity) if current
      puts "#EVAL#"
      puts "unset AWS_ACTIVE_ACCOUNT AWS_SESSION_EXPIRY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_ACTIVE_IDENTITY"
    end

    def show_creds(fqn)
      creds = @cred_store.base_creds(to_path(fqn))
      if creds
        puts "Stored base credentials for #{white(fqn)}"
        puts "AWS_ACCESS_KEY_ID=#{creds.access_key_id}"
        puts "AWS_SECRET_ACCESS_KEY=#{creds.secret_access_key}"
      else
        puts "No base credentials stored for #{fqn} account"
      end

    end

    def replace_creds(fqn)
      request_base_creds(account(fqn))
    end

    def rotate_creds(fqn)
      puts "Not implemented yet"
    end

    def initialize
      # init aws
      # aws-sdk is slow, so load it only when needed
      require 'aws-sdk-core'
      Aws.config.update(:http_proxy => ENV['https_proxy'])
      # init config
      @config = deep_merge(yaml('auth'), yaml('auth-keys'))
      # init creds store
      force_storage = @config['force_storage']
      STDERR.puts yellow("Credential storage is forced to #{force_storage}") if force_storage
      @cred_store = CredentialsStore.get(force_storage)
    end

    def user
      @config['username']
    end

    def account(fqn)
      path = to_path(fqn)
      acc_cfg = @config['accounts'].dig(*path)
      unless acc_cfg
        STDERR.puts red("ERROR! Account #{fqn} not found in config")
        exit 1
      end

      acc = OpenStruct.new(acc_cfg)
      acc.fqn = fqn
      acc.path = path

      acc
    end

    def credentials(creds, expiry, identity)
      OpenStruct.new(creds: creds, expiry: expiry, identity: identity)
    end

    def request_base_creds(acc)
      STDERR.puts "Please provide base AWS credentials for #{white(acc.fqn)}"
      STDERR.puts "Enter AWS_ACCESS_KEY_ID:"
      key_id = STDIN.gets.chomp

      STDERR.puts "Enter AWS_SECRET_ACCESS_KEY:"
      secret_key = STDIN.gets.chomp

      creds = Aws::Credentials.new(key_id, secret_key)
      @cred_store.save_base_creds(acc.path, creds)

      creds
    end

    def base_creds(acc)
      if acc.key_id && acc.secret_key
        creds = Aws::Credentials.new(acc.key_id, acc.secret_key)
      else
        creds = @cred_store.base_creds(acc.path) || request_base_creds(acc.path)
      end
      creds
    end

    def login_bare(acc)
      cached = @cred_store.temp_creds(acc.path, user)
      return credentials(cached[:creds], cached[:expiry], user) if cached

      mfa_arn = "arn:aws:iam::#{acc.acc_id}:mfa/#{user}"
      sts = Aws::STS::Client.new(credentials: base_creds(acc), region: region)

      STDERR.puts "Enter MFA for #{acc.fqn}"
      token = STDIN.gets.chomp
      begin
        session = sts.get_session_token(duration_seconds: SESSION_DURATION_SECONDS,
                                        serial_number: mfa_arn,
                                        token_code: token)
        creds = Aws::Credentials.new(session.credentials.access_key_id,
                                     session.credentials.secret_access_key,
                                     session.credentials.session_token)
      rescue Exception => e
        STDERR.puts red("ERROR! Unable to obtain credentials for #{acc.fqn}")
        STDERR.puts white(e.message)
        exit 1
      end

      STDERR.puts green("Successfully obtained creds for #{acc.fqn}")
      @cred_store.save_temp_creds(acc.path, user, creds, session.credentials.expiration)
      credentials(creds, session.credentials.expiration, user)
    end

    def login_role(acc, role)
      active_role = role || acc.role || DEFAULT_ROLE_NAME
      role_arn = "arn:aws:iam::#{acc.acc_id}:role/#{active_role}"

      cached = @cred_store.temp_creds(acc.path, active_role)
      return credentials(cached[:creds], cached[:expiry], active_role) if cached

      parent_acc = account(acc.parent)
      parent_creds = login_bare(parent_acc)[:creds]
      sts = Aws::STS::Client.new(credentials: parent_creds,
                                 endpoint: 'https://sts.ap-southeast-2.amazonaws.com',
                                 region: region)
      begin
        creds = sts.assume_role(role_arn: role_arn,
                                role_session_name: "#{user}-#{parent_acc.path.join('-')}",
                                duration_seconds: 3600).credentials
      rescue Exception => e
        STDERR.puts red("ERROR! Unable to obtain credentials for #{acc.fqn}")
        STDERR.puts white(e.message)
        exit 1
      end
      STDERR.puts green("Successfully obtained creds for #{acc.fqn}")
      @cred_store.save_temp_creds(acc.path, active_role, creds, creds.expiration)

      credentials(creds, creds.expiration, active_role)
    end

    def print_creds(acc, creds)
      puts "#EVAL#"
      puts "export AWS_ACTIVE_ACCOUNT=#{acc.fqn}"
      puts "export AWS_ACTIVE_IDENTITY=#{creds.identity}"
      puts "export AWS_SESSION_EXPIRY=\"#{creds.expiry}\""
      puts "export AWS_ACCESS_KEY_ID=#{creds.creds.access_key_id}"
      puts "export AWS_SECRET_ACCESS_KEY=#{creds.creds.secret_access_key}"
      puts "export AWS_SESSION_TOKEN=#{creds.creds.session_token}"
    end

  end
end