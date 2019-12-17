require 'os'
require_relative 'gnome_dbus'
require_relative 'mac_keychain'
require_relative 'flat_file'

module Sty
  class CredentialsStore

    def self.get(force_file)
      case
      when force_file
        return FlatFile.new
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