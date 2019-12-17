require_relative 'base_store'

module Sty
  class TextFile < BaseStore
    include Sty::Util

    private

    def delete_stored_entry(path, identity)
      begin
        File.delete(cache_file(path, identity))
      rescue Errno::ENOENT => e
      end
    end

    def load_from_store(path, identity)
      begin
        return Psych.load_file(cache_file(path, identity))
      rescue Errno::ENOENT
      end
    end

    def save_to_store(path, identity, hash)
      File.open(cache_file(path, identity), 'w') do |file|
        file.write(Psych.dump(hash))
      end
    end

    def cache_file(path, identity)
      "#{dir}/auth-cache/#{path.join('-')}-#{identity}.yaml"
    end

  end
end