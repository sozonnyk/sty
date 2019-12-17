require 'os'
require_relative 'gnome_dbus'
require_relative 'mac_keychain'
require_relative 'kde_wallet'
require_relative 'text_file'

module Sty
  class CredentialsStore

    def self.get(force_storage)
      case
      when force_storage
        return instance(force_storage)
      when OS.linux?
        return GnomeDbus.new
      when OS.mac?
        return MacKeychain.new
      else
        fail "Sty only works on Mac or Linux"
      end
    end

    def self.instance(name)
      clazz_name = name.split('_').collect(&:capitalize).join
      clazz = Sty.const_get(clazz_name)
      clazz.new if clazz
    end

  end

end