module Sty
  class BaseStore
    include Sty::Util
    BASE_CREDS_ID = '[BASE]'

    def base_creds(path)
      hash = load_from_store(path, BASE_CREDS_ID)
      Aws::Credentials.new(hash['access_key_id'], hash['secret_access_key']) if hash
    end

    def save_base_creds(path, creds)
      save_to_store(path, BASE_CREDS_ID, {'access_key_id' => creds.access_key_id,
                                          'secret_access_key' => creds.secret_access_key})
    end

    def temp_creds(path, identity)
      acc_fqn = to_fqn(path)
      cached_creds = load_from_store(path, identity)

      unless cached_creds
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

    def save_temp_creds(path, identity, creds, expiration)
      creds_hash = {'access_key_id' => creds.access_key_id,
                    'secret_access_key' => creds.secret_access_key,
                    'session_token' => creds.session_token,
                    'expiration' => expiration }
      save_to_store(path, identity, creds_hash)
    end

    def delete_creds(path, identity)
      delete_stored_entry(path, identity)
    end

    private

    def delete_stored_entry(path, identity)
      raise NotImplementedError
    end

    def load_from_store(path, identity)
      raise NotImplementedError
    end

    def save_to_store(path, identity, hash)
      raise NotImplementedError
    end

  end
end