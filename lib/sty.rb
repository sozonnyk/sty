trap "INT" do
  $stderr.reopen(IO::NULL)
  $stdout.reopen(IO::NULL)
  exit 1
end

require_relative 'sty/cli'