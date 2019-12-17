require 'keychain'
require 'base64'
require_relative 'base_store'

module Sty
  class MacKeychain < BaseStore

    CHAIN_NAME = 'sty'
    CHAIN_LOCK_TIMEOUT = 8 * 60 * 60
    CHAIN_LOCK_ON_SLEEP = false

    def initialize
      @chain = Keychain.open(CHAIN_NAME)
      unless @chain.exists?
        STDERR.puts "New keychain named \"#{green(CHAIN_NAME)}\" will be created in \"~/Library/Keychains/\" to store your AWS credentials"
        STDERR.puts red("You must remember the password you supply as it will be required to unlock keychain.")
        STDERR.puts "Press [#{green('ENTER')}] to continue."
        STDIN.gets
        @chain = Keychain.create(CHAIN_NAME)
        @chain.lock_interval = CHAIN_LOCK_TIMEOUT
        @chain.lock_on_sleep = CHAIN_LOCK_ON_SLEEP
      end
    end

    private

    def delete_stored_entry(path, identity)
      unlock
      item = item(path, identity)
      item.delete if item
    end

    def load_from_store(path, identity)
      unlock
      item = item(path, identity)
      return Psych.load(Base64.decode64(item.password)) if item
    end

    def save_to_store(path, identity, hash)
      unlock
      secret = Base64.encode64(Psych.dump(hash))
      item = item(path, identity)
      if item
        item.password = secret
        item.save!
      else
        @chain.generic_passwords.create(service: item_name(path, identity), password: secret)
      end
    end

    def item(path, identity)
      @chain.generic_passwords.where(service: item_name(path, identity)).all.first
    end

    def item_name(path, identity)
      "#{path.join('-')}-#{identity}"
    end

    def unlock
      begin
        @chain.unlock! if @chain.locked?
      rescue Exception => e
        STDERR.puts red("Unable to unlock the keychain.")
        STDERR.puts white(e.message)
        exit 1
      end

    end

  end
end