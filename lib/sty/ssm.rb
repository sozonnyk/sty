require_relative 'util'
require 'pathname'
require 'uri'
require 'json'

module Sty
  class Ssm
    include Sty::Util

    MINIMAL_AGENT_VERSION = '2.3.612.0'
    DEFAULT_REGION = 'ap-southeast-2'
    SSM_PLUGIN = "/usr/local/bin/session-manager-plugin"

    def initialize
      require 'aws-sdk-ec2'
      require 'aws-sdk-ssm'
      Aws.config.update(:http_proxy => ENV['https_proxy'])
    end

    def region
      ENV['AWS_REGION'] || DEFAULT_REGION
    end

    def ec2
      @ec2 = @ec2 || Aws::EC2::Client.new(region: region)
    end

    def ssm
      @ssm = @ssm || Aws::SSM::Client.new(region: region)
    end

    def all_ec2_instances
      ec2.describe_instances.map do |page|
        page.reservations.map { |r| r.instances }
      end.flatten
    end

    def all_ssm_details
      ssm.describe_instance_information.map do |page|
        page.instance_information_list
      end.flatten
    end

    def ssm_details
      @ssm_details = @ssm_details || all_ssm_details.map do |i|
        [i.instance_id, i]
      end.to_h
    end

    def instance_id(instance)
      instance.instance_id
    end

    def instance_name(instance)
      name_tag = instance.tags.select { |t| t.key == 'Name' }.first
      name_tag ? name_tag.value : "None"
    end

    def instance_ips(instance)
      instance.network_interfaces.map { |n| n.private_ip_address }
    end

    def extract_fields(inst)
      [instance_name(inst), instance_id(inst)] + instance_ips(inst)
    end

    def prepare_regex(names)
      names = ['.'] if names.empty?
      names.map { |n| Regexp.new(Regexp.quote(n), Regexp::IGNORECASE) }
    end

    def win?(instance)
      instance.platform =~ /windows/i
    end

    def platform(instance)
      win?(instance) ? magenta("[Win] ") : ""
    end

    def ping(instance)
      status = ssm_details[instance_id(instance)]&.ping_status || 'Unavailable'
      version_str = ssm_details[instance_id(instance)]&.agent_version
      version = Gem::Version.new(version_str || '0')
      reference_version = Gem::Version.new(MINIMAL_AGENT_VERSION)
      old_version = version < reference_version

      result = "[#{status}#{old_version ? ', old agent' : ''}]"

      case
      when status == 'Online' && !old_version
        green(result)
      when status == 'Online' && old_version
        yellow(result)
      else
        red(result)
      end

    end

    def find(instances, names)
      re = prepare_regex(names)
      instances.select do |i|
        i.state.name == 'running' &&
            extract_fields(i).any? { |f| re.all? { |r| f =~ r } }
      end.sort { |a, b| instance_name(a) <=> instance_name(b) }
    end

    def print_refine_instances(instances, type)
      puts "Please refine #{type} instance:"
      instances.each_with_index do |inst, idx|
        puts "#{idx}: #{instance_id(inst)} #{ping(inst)} [#{instance_name(inst)}] #{platform(inst)}(#{instance_ips(inst).join(', ')}) "
      end
    end

    def refine(found)
      if found.size > 1
        refine = nil
        loop do
          yield(found)
          refine = Integer(STDIN.gets.chomp) rescue false
          break if refine && refine < found.size
        end
        target = found[refine]
      else
        target = found.first
      end
      target
    end


    def session_manager
      unless Pathname.new(SSM_PLUGIN).exist?
        puts red("SSM plugin is not found: #{SSM_PLUGIN}.")
        puts white("You must have SSM plugin to continue.\nSee: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html")
        exit 1
      end
      SSM_PLUGIN
    end

    def connect(search)

      found = find(all_ec2_instances, search)
      if found.empty?
        puts "No instances found for search terms: #{search.join(', ')}"
        exit 1
      end
      target = refine(found) { |found| print_refine_instances(found, 'target') }

      begin
        resp = ssm.start_session(target: instance_id(target))
      rescue Exception => e
        puts red("ERROR! Unable to start session")
        puts white(e.message)
        exit 1
      end

      mappings = {session_id: 'SessionId', token_value: 'TokenValue', stream_url: 'StreamUrl'}
      reqest_str = resp.to_h.map { |k, v| [mappings[k], v] }.to_h.to_json
      exec "#{session_manager} \'#{reqest_str}\' ap-southeast-2 StartSession"
    end

  end
end