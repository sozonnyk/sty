require 'os'
require_relative 'gnome_dbus'
require_relative 'mac_keychain'

module Sty
  class CredentialsStore

    def self.get
      case
      when OS.linux?
        return GnomeDbus.new
      when OS.mac?
        return MacKeychain.new
      else
        fail "Sty only works on Mac or Linux"
      end
    end

  end

end