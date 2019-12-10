require 'rubygems'
require 'fileutils'

Gem.post_uninstall do |gem|
  return unless gem.spec.name == "sty"

  exe = '/usr/local/bin/sty'
  sty_home = File.expand_path('~/.sty')

  begin
    FileUtils.rm(exe) if File.exist?(exe)
  rescue Errno::EPERM, Errno::EACCES => e
    puts "No permission to delete #{dst}, let's try with sudo."
    `sudo rm -f #{exe}`
  end

  puts "Remove ALL configuration in #{sty_home}? [yN]:"
  ansver = $stdin.gets.chomp
  if ansver =~ /^y$/i && File.exist?(sty_home)
    FileUtils.rm_rf(sty_home)
  end

end