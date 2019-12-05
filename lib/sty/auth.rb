require_relative 'functions'

class Auth

  def initialize
    @config = yaml('auth')
  end

  def login(fqn)
    acc = account(to_path(fqn))
    puts "#EVAL# \n echo \"#{acc}\""
  end

  def logout
    current = ENV['AWS_ACTIVE_ACCOUNT']
    identity = ENV['AWS_ACTIVE_IDENTITY']
    STDERR.puts "Logging off from: #{white(current)}"
    #cache = cache_file(to_path(current),identity)
    #begin
    #  File.delete(cache)
    #rescue Errno::ENOENT => e
    #end
    puts "unset AWS_ACTIVE_ACCOUNT AWS_SESSION_EXPIRY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_ACTIVE_IDENTITY"
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

  def print_creds(path)
    STDOUT.puts "export AWS_ACTIVE_ACCOUNT=#{path}"
    # STDOUT.puts "export AWS_ACTIVE_IDENTITY=#{creds[:identity]}"
    # STDOUT.puts "export AWS_SESSION_EXPIRY=\"#{creds[:expiry]}\""
    # STDOUT.puts "export AWS_ACCESS_KEY_ID=#{creds[:creds].access_key_id}"
    # STDOUT.puts "export AWS_SECRET_ACCESS_KEY=#{creds[:creds].secret_access_key}"
    # STDOUT.puts "export AWS_SESSION_TOKEN=#{creds[:creds].session_token}"
  end



end