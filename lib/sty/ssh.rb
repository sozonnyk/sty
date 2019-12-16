require_relative 'util'
require 'uri'

module Sty
  class Ssh
    include Sty::Util

    def initialize
      require 'aws-sdk-ec2'
      Aws.config.update(:http_proxy => ENV['https_proxy'])
    end

    def all_instances
      instances = []
      options = {}

      loop do
        resp = ec2.describe_instances(options)
        instances += resp.reservations.map { |r| r.instances }.flatten
        break unless resp.next_token
        options[:next_token] = resp.next_token
      end

      instances
    end

    def valid_key_file?(key_name, key_file)
      aws_fp = ec2.describe_key_pairs(key_names: [key_name]).key_pairs[0].key_fingerprint
      calculated_fp = `openssl pkcs8 -in #{key_file} -nocrypt -topk8 -outform DER | openssl sha1 -c`.chomp
      aws_fp == calculated_fp
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

    def find(instances, names)
      re = prepare_regex(names)
      instances.select do |i|
        i.state.name == 'running' &&
            extract_fields(i).any? { |f| re.all? { |r| f =~ r } }
      end.sort { |a, b| instance_name(a) <=> instance_name(b) }
    end

    def win?(instance)
      instance.platform =~ /windows/i
    end

    def platform(instance)
      win?(instance) ? " [Win] " : ""
    end

    def print_refine_instances(instances, type)
      puts "Please refine #{type} instance:"
      instances.each_with_index do |inst, idx|
        puts "#{idx}: #{instance_id(inst)} [#{instance_name(inst)}] #{platform(inst)}(#{instance_ips(inst).join(', ')}) "
      end
    end

    def print_refine_ips(ips)
      puts 'Please refine IP address:'
      ips.each_with_index do |ip, idx|
        puts "#{idx}: #{ip}"
      end
    end

    #Not used anymore
    def print_refine_keys(keys)
      puts 'Please refine key:'
      keys.each_with_index do |key, idx|
        puts "#{idx}: #{key}"
      end
    end

    def find_path(hash, path)
      path.split('/').reduce(hash) { |memo, path| memo[path] if memo }
    end

    def path?(str)
      str =~ /\//
    end

    def path_error(path)
      puts red("ERROR ! No jumphost found for #{path}")
      exit 1
    end

    def config
      @config = @config || yaml('ec2')
    end

    def ec2
      @ec2 = @ec2 || Aws::EC2::Client.new
    end

    def auth_config
      @auth_config = @auth_config || yaml('auth-keys')
    end

    def username
      auth_config['ec2-username'] || auth_config['username']
    end

    def key_dir
      ssh_keys = auth_config['ssh-keys']
      ssh_keys = "#{dir}/#{ssh_keys}" unless ssh_keys =~ /^\/|^~/
      ssh_keys
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

    def find_jumphost_from_config(act_acc, platform)
      jumphosts = find_path(config, act_acc)

      unless jumphosts
        puts red("No jumphost configured for #{act_acc}")
        exit 1
      end

      path_error(act_acc) unless jumphosts

      if path?(jumphosts)
        jumphost_path = jumphosts
        jumphosts = find_path(config, jumphost_path)
      end

      path_error(jumphost_path) unless jumphosts

      jumphosts[platform]
    end

    def find_instance(args, type)
      found = find(all_instances, args)
      if found.empty?
        puts "No instances found for search terms: #{args.join(', ')}"
        exit 1
      end
      target = refine(found) { |found| print_refine_instances(found, type) }
      ip = refine(instance_ips(target)) { |found| print_refine_ips(found) }
      OpenStruct.new(ip: ip,
                     platform: win?(target) ? 'windows' : 'linux',
                     key_name: target.key_name)
    end

    def find_key(key_name)

      keys_glob = Dir.glob("#{key_dir}/**/#{key_name}.pem")

      if keys_glob.size < 1
        puts red("ERROR! Unable to find key #{key_name}.pem within #{key_dir}")
        exit 1
      end

      key = keys_glob.detect do |key_file|
        valid_key_file?(key_name, key_file)
      end

      unless key
        puts red("ERROR! There is no key file with matching fingerprint")
        exit 1
      end

      key
    end

    def print_command(cmd)
      puts "Generated command:\n------------------------\n#{cmd}"
      puts '------------------------'
    end

    def connect(search, no_jumphost, jumphost_override, target_key)

      no_strict = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
      server_alive = "-o ServerAliveInterval=25"
      ec2_user = 'ec2-user'

      opts = []
      opts << 'no_jumphost' if no_jumphost
      opts << 'select_jumphost' if jumphost_override
      opts << 'use_key' if target_key
      puts "Enabled options: #{opts.join(', ')}"
      puts "Requested search terms: #{search.join(', ')}"

      puts "Active account: #{act_acc}"

      instance = find_instance(search, 'target')

      if instance.platform == 'windows'

#      username=s:#{username}
#
        jumphost = find_jumphost_from_config(act_acc, instance.platform)
        cmd = %W(
      rdp://gatewayusagemethod:i:1
      gatewaycredentialssource:i:4
      gatewayprofileusagemethod:i:1
      promptcredentialonce:i:0
      gatewaybrokeringtype:i:0

      gatewayhostname=s:#{jumphost}
      full\ address=s:#{instance.ip}
        )
        cmd = URI.escape(cmd.join('&'))
        cmd = "open \"#{cmd}\""

      else

        proxy = ''
        unless no_jumphost

          if jumphost_override
            puts 'Type jumphost search terms:'
            jumphost_query = STDIN.gets.chomp
            jh_instance = find_instance([jumphost_query], 'jumphost')
            jh_key = find_key(jh_instance.key_name)
            jh_string = "-i #{jh_key} #{ec2_user}@#{jh_instance.ip}"
          else
            jumphost = find_jumphost_from_config(act_acc, instance.platform)
            jh_string = "#{username}@#{jumphost}"
          end

          proxy = "-o ProxyCommand='ssh #{server_alive} #{no_strict} #{jh_string} nc #{instance.ip} 22'"
        end


        if target_key
          key = find_key(instance.key_name)
          target_string = "-i #{key} #{ec2_user}@#{instance.ip}"
        else
          target_string = "#{username}@#{instance.ip}"
        end

        cmd = "ssh #{proxy} #{no_strict} #{server_alive} #{target_string}"

      end
      print_command(cmd)
      exec cmd

    end
  end
end
