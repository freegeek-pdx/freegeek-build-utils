require 'json'
require 'cgi'
require 'net/http'

class FGJSONAPI
  attr_accessor :server, :namespace

  def initialize(ser, name)
    @namespace = name.sub(/urn:/, "")
    @server = ser
  end

  def add_method(*params)
    true
  end

  def method_missing(*params)
    method = params.shift.to_s
    params = params.to_json
    url = "#{server}api/#{namespace}/#{method}"
    uri = URI(url)
    ret = Net::HTTP.post_form(uri, 'request' => params).body
    j = JSON.parse(ret)
    if j["status"].nil?
      raise SOAP::ResponseFormatError
    elsif j["status"] != "success"
      raise(SOAP::FaultError.new(j["message"]))
    else
      return j["result"]
    end
  end
end

module SOAP
  class FaultError < Exception
  end

  class RPCRoutingError < Exception
  end

  class ResponseFormatError < Exception
  end

  module RPC
    Driver = FGJSONAPI
  end
end

#driver = SOAP::RPC::Driver.new("http://127.0.0.1:3000/", "urn:printme")
#driver.add_method("blah")
#puts driver.ping
