require "ppphandler/version"
require 'uri'
require 'net/http'
require 'openssl'

module PPPHandler

  def get_local_ip_addr_from_nic(nic)
    local_addresses = Socket.getifaddrs.select{|it|
      it.addr && it.addr.ipv4?
    }.find{ |it|
      it.name.match(%r`#{nic}`)
    }.try(:addr).try(:ip_address)
  end

  def current_global_ip_address(nic = nil)
    uri = URI.parse("https://api.ipify.org/")
    http = Net::HTTP.new(uri.host, 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.local_host = get_local_ip_addr_from_nic(nic) if nic
    res = http.get(uri.path)
    res.body
  end

  def ifexists?(nic)
    `ifconfig #{nic} > /dev/null 2>&1`
    $? == 0 && local_addr(nic)
  end

  def procexists?(proc)
    `pgrep #{proc} > /dev/null 2>&1`
    $? == 0
  end

  def ifup(provider, nic)
    begin
      timer = 0
      loop do
        unless procexists?('pppd')
          `pon #{provider}`
        end
        return if ifexists?(nic)
        sleep 0.2
        timer += 0.2
        if timer > 40
          ifdown(provider, nic)
        end
      end
    rescue
      sleep 20
      retry
    end
  end

  def ifdown(provider, nic)
    begin
      loop do
        `poff #{provider}` if procexists?('pppd')
        sleep 1
        return unless ifexists?(nic)
        sleep 3
      end
    rescue
      sleep 20
      retry
    end
  end

  def local_addr(nic)
    local_address = Socket.getifaddrs.select{|it|
      it.addr && it.addr.ipv4?
    }.find{|it|
      it.name == nic
    }
  end

end

if __FILE__ == $PROGRAM_NAME
  def get_global_ip_address(nic = :default)
    uri = URI.parse('https://api.ipify.org/')
    http = Net::HTTP.new(uri.host, 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.local_host = get_local_ip_addr_from_nic(nic) if nic && nic != :default
    res = http.get(uri.path)
    res.body
  end
  nic = ARGV[0]
  provider = ARGV[1]
  if nic && provider
    loop.with_index(1) do |_, i|
      PPPHandler.ifup
      ip = get_global_ip_address(nic)
      time = Time.now
      puts "%s %s" % [ time, ip ]
      PPPHandler.ifdown
      sleep 3
    end
  end
end
