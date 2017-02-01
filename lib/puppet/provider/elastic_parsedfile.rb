require 'puppet/provider/parsedfile'

class Puppet::Provider::ElasticParsedFile < Puppet::Provider::ParsedFile

  def self.shield_config val
    @default_target ||= case Facter.value('osfamily')
      when 'OpenBSD'
        "/usr/local/elasticsearch/shield/#{val}"
      else
        "/usr/share/elasticsearch/shield/#{val}"
      end
  end

  def self.xpack_config val
    @default_target ||= "/etc/elasticsearch/x-pack/#{val}"
  end
end
