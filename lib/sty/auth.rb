require_relative 'functions'
require_relative 'dig'

SESSION_DURATION_SECONDS = 43_200
DEFAULT_ROLE_NAME = 'ReadOnlyRole'
DEFAULT_REGION = 'ap-southeast-2'

class Auth

  def logout
    current = ENV['AWS_ACTIVE_ACCOUNT']
    identity = ENV['AWS_ACTIVE_IDENTITY']
    STDERR.puts "Logging off from: #{white(current)}"
    if current
      cache = cache_file(to_path(current),identity)
      begin
        File.delete(cache)
      rescue Errno::ENOENT => e
      end
    end
    puts "#EVAL#"
    puts "unset AWS_ACTIVE_ACCOUNT AWS_SESSION_EXPIRY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_ACTIVE_IDENTITY"
  end

  def deep_merge(h1,h2)
    h1.merge(h2){|k,v1,v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? deep_merge(v1,v2) : v2}
  end

  def initialize
    #aws-sdk is slow, so load it only when needed
    require 'aws-sdk-core'
    Aws.config.update(:http_proxy => ENV['https_proxy'])
    @config = deep_merge(yaml('auth'),yaml('auth-keys'))
  end

  def check_proxy
    unless ENV.find { |k,v| k =~ /HTTPS_PROXY/i }
      STDERR.puts red("WARNING! \"https_proxy\" env variable is not set.")
    end
  end

  def user
    @config['username']
  end

  def account(path)
    acc = @config['accounts'].dig(*path)
    unless acc
      STDERR.puts red("ERROR! Account #{to_fqn(path)} not found in config")
      exit 1
    end

    acc['path'] = path
    acc
  end

  def parent(acc)
    acc['parent']
  end

  def cached_creds(path, identity)
    acc_fqn = to_fqn(path)
    begin
      cached_creds = Psych.load_file(cache_file(path, identity))
      raise(RuntimeError) unless cached_creds
    rescue Errno::ENOENT, RuntimeError
      STDERR.puts "No cached creds for #{acc_fqn}"
      return nil
    end

    remained_minutes = ((cached_creds['expiration'] - Time.now) / 60).to_i

    if remained_minutes > 0
      STDERR.puts "Loaded cached creds for #{acc_fqn}"
      STDERR.puts "Credentials will stay active for the next #{remained_minutes} min"
      return {creds: Aws::Credentials.new(cached_creds['access_key_id'],
                                          cached_creds['secret_access_key'],
                                          cached_creds['session_token']),
              expiry: cached_creds['expiration']}
    else
      STDERR.puts "Cached creds for #{acc_fqn} expired"
    end
  end

  def save_creds(acc, creds, expiration, identity)
    creds_hash = {'access_key_id' => creds.access_key_id,
                  'secret_access_key' => creds.secret_access_key,
                  'session_token' => creds.session_token,
                  'expiration' => expiration
    }
    File.open(cache_file(acc['path'], identity), 'w') do |file|
      file.write(Psych.dump(creds_hash))
    end
  end

  def login_bare(acc)

    path = acc['path']
    acc_fqn = to_fqn(path)

    cached = cached_creds(path, user)
    return { creds: cached[:creds], expiry: cached[:expiry], identity: user } if cached

    STDERR.puts "Enter MFA for #{acc_fqn}"
    token = STDIN.gets.chomp

    mfa = "arn:aws:iam::#{acc['acc_id']}:mfa/#{user}"

    bare_creds = Aws::Credentials.new(acc['key_id'], acc['secret_key'])

    sts = Aws::STS::Client.new(credentials: bare_creds, region: region)

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

    save_creds(acc, creds, session.credentials.expiration, user)

    {creds: creds, expiry: session.credentials.expiration, identity: user}
  end

  def login_role(acc, role)
    path = acc['path']
    active_role = role || acc['role'] || DEFAULT_ROLE_NAME
    role_arn = "arn:aws:iam::#{acc['acc_id']}:role/#{active_role}"

    cached = cached_creds(path, active_role)
    return { creds: cached[:creds], expiry: cached[:expiry], identity: active_role } if cached

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
    save_creds(acc, creds, creds.expiration, active_role)

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

end