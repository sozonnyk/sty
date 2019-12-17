require_relative 'util'
require_relative 'dig'
require_relative 'credentials/credentials_store'

module Sty
  class Auth
    include Sty::Util

    SESSION_DURATION_SECONDS = 43_200
    DEFAULT_ROLE_NAME = 'ReadOnlyRole'
    DEFAULT_REGION = 'ap-southeast-2'

    def test
      store = Sty::CredentialsStore.get
      puts store
    end

    def login(fqn, role = nil)
      check_proxy
      acc = account(to_path(fqn))
      if parent(acc)
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

    def initialize
      # aws-sdk is slow, so load it only when needed
      require 'aws-sdk-core'
      Aws.config.update(:http_proxy => ENV['https_proxy'])
      @config = deep_merge(yaml('auth'), yaml('auth-keys'))
      @cred_store = CredentialsStore.get(false)
    end

    def user
      @config['username']
    end

    def account(path)
      acc = @config['accounts'].dig(*path)
      unless acc

        require 'pry'
        binding.pry

        STDERR.puts red("ERROR! Account #{to_fqn(path)} not found in config")
        exit 1
      end

      acc['path'] = path
      acc
    end

    def parent(acc)
      acc['parent']
    end

    def base_creds(acc)
      path = acc['path']
      acc_fqn = to_fqn(path)

      if acc['key_id'] && acc['secret_key']
        creds = Aws::Credentials.new(acc['key_id'], acc['secret_key'])
      else
        creds = @cred_store.base_creds(path)
      end

      unless creds
        STDERR.puts "Please provide base AWS credentials for #{white(acc_fqn)}"
        STDERR.puts "Enter KEY_ID:"
        acc['key_id'] = STDIN.gets.chomp

        STDERR.puts "Enter SECRET_KEY:"
        acc['secret_key'] = STDIN.gets.chomp

        creds = Aws::Credentials.new(acc['key_id'], acc['secret_key'])
        @cred_store.save_base_creds(path, creds)
      end

      creds
    end

    def login_bare(acc)

      path = acc['path']
      acc_fqn = to_fqn(path)

      cached = @cred_store.temp_creds(path, user)
      return {creds: cached[:creds], expiry: cached[:expiry], identity: user} if cached

      mfa = "arn:aws:iam::#{acc['acc_id']}:mfa/#{user}"
      sts = Aws::STS::Client.new(credentials: base_creds(acc), region: region)

      STDERR.puts "Enter MFA for #{acc_fqn}"
      token = STDIN.gets.chomp

      begin
        session = sts.get_session_token(duration_seconds: SESSION_DURATION_SECONDS,
                                        serial_number: mfa,
                                        token_code: token)

        creds = Aws::Credentials.new(session.credentials.access_key_id,
                                     session.credentials.secret_access_key,
                                     session.credentials.session_token)
      rescue Exception => e
        STDERR.puts red("ERROR! Unable to obtain credentials for #{acc_fqn}")
        STDERR.puts white(e.message)
        exit 1
      end

      STDERR.puts green("Successfully obtained creds for #{acc_fqn}")

      @cred_store.save_temp_creds(acc['path'], user, creds, session.credentials.expiration)

      {creds: creds, expiry: session.credentials.expiration, identity: user}
    end

    def login_role(acc, role)
      path = acc['path']
      active_role = role || acc['role'] || DEFAULT_ROLE_NAME
      role_arn = "arn:aws:iam::#{acc['acc_id']}:role/#{active_role}"

      cached = @cred_store.temp_creds(path, active_role)
      return {creds: cached[:creds], expiry: cached[:expiry], identity: active_role} if cached

      parent_path = to_path(parent(acc))
      parent_acc = account(parent_path)
      parent_creds = login_bare(parent_acc)[:creds]
      sts = Aws::STS::Client.new(
          credentials: parent_creds,
          endpoint: 'https://sts.ap-southeast-2.amazonaws.com',
          region: region
      )
      begin
        creds = sts.assume_role(role_arn: role_arn,
                                role_session_name: "#{user}-#{parent_path.join('-')}",
                                duration_seconds: 3600).credentials
      rescue Exception => e
        STDERR.puts red("ERROR! Unable to obtain credentials for #{to_fqn(path)}")
        STDERR.puts white(e.message)
        exit 1
      end
      STDERR.puts green("Successfully obtained creds for #{to_fqn(path)}")
      @cred_store.save_temp_creds(acc['path'], active_role, creds, creds.expiration)

      {creds: creds, expiry: creds.expiration, identity: active_role}
    end

    def print_creds(acc, creds)
      puts "#EVAL#"
      puts "export AWS_ACTIVE_ACCOUNT=#{to_fqn(acc['path'])}"
      puts "export AWS_ACTIVE_IDENTITY=#{creds[:identity]}"
      puts "export AWS_SESSION_EXPIRY=\"#{creds[:expiry]}\""
      puts "export AWS_ACCESS_KEY_ID=#{creds[:creds].access_key_id}"
      puts "export AWS_SECRET_ACCESS_KEY=#{creds[:creds].secret_access_key}"
      puts "export AWS_SESSION_TOKEN=#{creds[:creds].session_token}"
    end

  end
end