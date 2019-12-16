require 'keychain'

module Sty
  class MacKeychain

    CHAIN_NAME = 'sty'

    def initialize
      @chain = Keychain.open(CHAIN_NAME)
      unless @chain.exists?
        STDERR.puts "New keychain named \"#{CHAIN_NAME}\" will be created in \"~/Library/Keychains/\" to store your AWS credentials\nPress [ENTER] to continue."
        STDIN.gets
        @chain = Keychain.create(CHAIN_NAME)
      end
      @chain.unlock!

    end




  end
end