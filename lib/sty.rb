trap "INT" do
  $stderr.reopen(IO::NULL)
  $stdout.reopen(IO::NULL)
  exit 1
end

#dir = File.expand_path(File.dirname(__FILE__))
#$LOAD_PATH.unshift(dir)
#
#puts $:

require_relative 'sty/cli'

#Sty::Cli.start(ARGV)