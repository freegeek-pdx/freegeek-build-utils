# This is a library. It does stuff.

require 'yaml'
f = File.open('/etc/printme.yml')
yaml = YAML.load(f.read)
f.close
keys = ['server', 'port']
if !(yaml.keys - keys == [] && keys - yaml.keys == [])
  puts "Invalid configuration file"
  exit 1
end
$server = yaml['server'] + ':' + yaml['port'].to_s

#configuration
# $server="printme:80"

$COLOR = true #make things cool
$PRINTME_VERSION=9

require 'rubytui'
require 'fileutils'
require 'soap/rpc/driver'
include FileUtils
include RubyTUI
require 'tempfile'

trap( "SIGINT" ) {
  `reset -Q`
  errorMessage "\n\nUser interrupt caught.  Exiting.\n\n"
  exit!( 1 )
}


def add_method(*args)
  @driver.add_method(*args)
end

  def add_methods
    # Connection Testing
    add_method("ping")
    # Version Checking
    add_method("version_compat", "client_version")
    add_method("version")
    add_method("bad_client_error")
    add_method("bad_server_error")
    # Lists
    add_method("actions")
    add_method("types")
    add_method("contracts")
    add_method("default_action_description")
    add_method("default_type_description")
    add_method("default_contract_label")
    # Printme
    add_method("empty_struct")
    add_method("submit", "printme_struct")
    # Notes
    add_method("empty_notes_struct")
    add_method("submit_notes", "notes_struct")
    add_method("get_system_for_note", "note_id")
    # Random Crap
    add_method("get_system_for_report", "report_id")
    add_method("contract_label_for_system", "system_id")
    add_method("type_description_for_system", "system_id")
    add_method("spec_sheet_url", "report_id")
    add_method("system_url", "system_id")
    add_method("get_system_id", "xml")
  end

def setup_soap
  @driver = SOAP::RPC::Driver.new("http://#{$server}/", "urn:printme")
  add_methods # copy from the api
end

def color(blah)
  puts colored(blah) if $debug
end

def realmain
  check_for_people_who_dont_read_the_instructions
  color "Setting up connection to the server..."
  setup_soap
  check_version
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
  if ENV['USER'] == "root"
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
  client_versions
end

def check_version
  begin
    retval = @driver.ping
    if retval != "pong"
      errorMessage "I could not connect to the server.\nMake sure you are connected to the network and try again.\n\n"
      exit false
    end
  rescue SOAP::RPCRoutingError, SOAP::ResponseFormatError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETDOWN, Errno::ENETUNREACH, Errno::ECONNRESET, Errno::ETIMEDOUT, NoMethodError, NameError => e
    errorMessage "I could not connect to the server (#{e.message}).\nMake sure you are connected to the network and try again.\n\n"
    exit false
  end
  if !@driver.version_compat($PRINTME_VERSION)
    errorMessage @driver.bad_client_error
    exit false
  end
  if !client_hash[$PRINTME_VERSION].include?(@driver.version)
    errorMessage @driver.bad_server_error
    exit false
  end
end

def runit(lshwname)
  return if $debug
  if File.exist?(lshwname)
    mv(lshwname, lshwname + '.old')
  end
  system("sudo lshw -xml>#{lshwname}")
end

def look_at_url(path)
  url="http://#{$server}#{path}"
  if ! system "firefox #{url}"
    puts url
  end
end