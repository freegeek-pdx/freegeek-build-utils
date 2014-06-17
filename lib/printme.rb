# This is a library. It does stuff.


require 'rubytui'

require 'yaml'
conffile = ENV["PRINTME_CONFIG"] || '/etc/printme.yml'
defaults = {'server' => 'printme', 'port' => 80}
yaml = defaults
if File.exists?(conffile)
  f = File.open(conffile)
  yaml = YAML.load(f.read)
  f.close
  keys = ['server', 'port']
  if !(yaml.keys - keys == [] && keys - yaml.keys == [])
    puts "Invalid configuration file"
    yaml = defaults.merge(yaml)
  end
end
$server = yaml['server'] + ':' + yaml['port'].to_s

class Hash
  def method_missing(*pams)
    n = pams.first.to_s
    if pams.length == 1 && (ret = self[n])
      return ret
    elsif pams.length == 2 && n.match(/=$/)
      self[n.sub(/=$/, "")] = pams[1]
    else
      super(*pams)
    end
  end
end

$PRINTME_VERSION=17

require 'rubytui'
require 'fileutils'
#require 'soap/rpc/driver'
require 'fgjsonapi'
include FileUtils
include RubyTUI
require 'tempfile'

if RubyTUI::DIST == "lucid"
  $COLOR = false
end

trap( "SIGINT" ) {
  `reset -Q`
  errorMessage "\n\nUser interrupt caught.  Exiting.\n\n"
  exit!( 1 )
}


def add_method(*args)
  @driver.add_method(*args)
end

def setup_soap
  @driver = SOAP::RPC::Driver.new("http://#{$server}/", "urn:printme")
  # Connection Testing and Version Checking, required before automagic stuff can happen
  add_method("ping")
  add_method("version_compat", "client_version")
  add_method("version")
  add_method("bad_client_error")
  add_method("bad_mac_client_error")
  add_method("bad_server_error")
  add_method("soap_methods")
end

def color(blah)
  puts colored(blah) if $debug
end

def soap_list_methods
  @soap_methods.map{|x| x[0]}
end

def soap_has_method?(check)
  soap_list_methods.include?(check)
end

def soap_arguments(function)
  return @soap_methods.select{|x| x[0] == function}.map{|x| x.shift; x}.first
end

def automagic
  @soap_methods = @driver.soap_methods
  @soap_methods.each{|x|
    add_method(*x)
  }
end

def realmain
  check_for_people_who_dont_read_the_instructions
  color "Setting up connection to the server..."
  setup_soap
  check_version
  automagic
  mymain
end

def main
  begin
    realmain
  rescue SOAP::FaultError => e
    errorMessage "Server returned this error: #{e.message}\n\n"
    exit 1
#  rescue NoMethodError, NameError
    errorMessage "There's a BUG in printme!\n\n"
    exit 1
  end
end

def check_for_people_who_dont_read_the_instructions
  if ENV['USER'] == "root" and ENV['ALLOW_ROOT'] != 'true'
    puts "DO NOT RUN PRINTME AS ROOT. if you are typing 'sudo printme', then that is incorrect. Just type 'printme'."
    exit 1
  end
end

def client_hash
  client_versions = Hash.new([])
  client_versions[1] = [1]      # dunno
  client_versions[2] = [2,3]    # first one that makes it here. forced upgrade.
  client_versions[3] = [3]      # forced upgrade
  client_versions[4] = [3,4]    # forced upgrade
  client_versions[5] = [5]      # forced. the server needs to clean the xml now since printme isn't.
  client_versions[6] = [6,7]      # forced. add contracts support.
  client_versions[7] = [6,7,8]      # forced. fix contracts support. (bad builder problem)
  client_versions[8] = [6,7,8]      # forced. fix contracts support. (my bugs)
  client_versions[9] = [9] # soap
  if File.basename($0) == "list-printmes" || File.basename($0) == "printme-note"
    client_versions[10] = [10] # notes
  else
    client_versions[10] = [9,10] # soap
  end
  client_versions[11] = [11]    # string change on both ends, that needs to go together (reworded contracts question)
  client_versions[12] = [12]    # new info collected (covered), forced upgrade. automagic.
  client_versions[13] = [12,13]    # all works.
  client_versions[14] = [14] # previous systems
  client_versions[15] = [15] # conditional Q's
  client_versions[16] = [16] # OR'ed conditional Q's
  client_versions[17] = [17] # requires updated server
  client_versions
end

def check_version
  begin
    retval = @driver.ping
    if retval != "pong"
      errorMessage "I could not connect to the server.\nMake sure you are connected to the network and try again.\n\n"
      exit false
    end
  rescue SOAP::RPCRoutingError, SOAP::ResponseFormatError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETDOWN, Errno::ENETUNREACH, Errno::ECONNRESET, Errno::ETIMEDOUT, NoMethodError, SocketError, NameError => e
    errorMessage "I could not connect to the server (#{e.message}).\nMake sure you are connected to the network and try again.\n\n"
    exit false
  end
  if !@driver.version_compat($PRINTME_VERSION)
    theirver = @driver.version
    if theirver > $PRINTME_VERSION # bug in older versions
      errorMessage (theirver >= 14 and DIST == "mac") ? @driver.bad_mac_client_error : @driver.bad_client_error + "\n"
      exit false
    end
  end
  if client_hash[$PRINTME_VERSION].class == Array && !client_hash[$PRINTME_VERSION].include?(@driver.version)
    errorMessage @driver.bad_server_error + "\n"
    exit false
  end
end

def runit(lshwname)
  return if !STDIN.tty? && File.exist?(lshwname)
  if File.exist?(lshwname)
    mv(lshwname, lshwname + '.old')
  end
 if DIST == "mac"
system_check_ret("system_profiler -xml>#{lshwname}")
else
  system_check_ret("sudo lshw -xml>#{lshwname}")
end
  if File.readlines(lshwname).length == 0
    errorMessage "ERROR: lshw outputted nothing. This may be a bug in lshw. Aborting.\n\n"
    exit 1
  end
end

def system_check_ret(str)
  ret = system(str)
  if ! ret
    errorMessage "Failed to run command, aborting.\n\n"
    exit 1
  end
end

def download_url(path, result)
  system("wget -q http://#{$server}#{path} -O #{result}")
end

def look_at_url(path)
  url="http://#{$server}#{path}"
  command = "firefox #{url}"
  if DIST == "mac"
    command = command.sub("firefox", "open")
  else
    command = command + " 2>&1 | tee -a /var/log/freegeek-extras/printme.log >/dev/null"
  end
  puts "Opening spec sheet in web browser: #{url}"
  system command
end
