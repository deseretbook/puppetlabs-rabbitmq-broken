require 'json'
require 'puppet'
Puppet::Type.type(:rabbitmq_binding).provide(:rabbitmqadmin) do

  if Puppet::PUPPETVERSION.to_f < 3
    commands :rabbitmqctl   => 'rabbitmqctl'
    commands :rabbitmqadmin => '/usr/local/bin/rabbitmqadmin'
  else
    has_command(:rabbitmqctl, 'rabbitmqctl') do
      environment :HOME => "/tmp"
    end
    has_command(:rabbitmqadmin, '/usr/local/bin/rabbitmqadmin') do
      environment :HOME => "/tmp"
    end
  end
  defaultfor :feature => :posix

  def should_vhost
    if @should_vhost
      @should_vhost
    else
      @should_vhost = resource[:name].split('@').last
    end
  end
  
  BINDING_INT_FIELDS = [['x-bound-from', 'hops']]

  def self.all_vhosts
    vhosts = []
    rabbitmqctl('list_vhosts', '-q').split(/\n/).collect do |vhost|
      vhosts.push(vhost)
    end
    vhosts
  end

  def self.all_bindings(vhost)
    rabbitmqctl('list_bindings', '-q', '-p', vhost, 'source_name', 'destination_name', 'destination_kind', 'routing_key', 'arguments').split(/\n/)
  end

  def self.instances
    resources = []
    all_vhosts.each do |vhost|
      all_bindings(vhost).collect do |line|
        source_name, destination_name, destination_type, routing_key, arguments = line.split(/\t/)
        # Convert output of arguments from the rabbitmqctl command to a json string.
        if !arguments.nil?
          arguments = arguments.gsub(/^\[(.*)\]$/, "").gsub(/\{("(?:.|\\")*?"),/, '{\1:').gsub(/\},\{/, ",")
          if arguments == ""
            arguments = '{}'
          end
        else
          arguments = '{}'
        end
        if (source_name != '')
          binding = {
            :destination_type => destination_type,
            :routing_key      => routing_key,
            :arguments        => JSON.parse(arguments),
            :ensure           => :present,
            :name             => "%s@%s@%s" % [source_name, destination_name, vhost],
          }
          resources << new(binding) if binding[:name]
        end
      end
    end
    resources
  end

  def self.prefetch(resources)
    packages = instances
    resources.keys.each do |name|
      if provider = packages.find{ |pkg| pkg.name == name }
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def clean_arguments
    # some fields must be integers etc.
    args = resource[:arguments]
    unless args.empty?
      BINDING_INT_FIELDS.each do |field|
        if field.is_a?(Array)
          field.each do |nested_field|
            z = args
            if nested_field == field.last
              z[nested_field] = z[nested_field].to_i
            else
              z = z[nested_field]
            end
          end
        elsif args.has_key?(field)
          args[field] = args[field].to_i
        end
      end
    end
    args
  end

  def create
    vhost_opt = should_vhost ? "--vhost=#{should_vhost}" : ''
    name = resource[:name].split('@').first
    destination = resource[:name].split('@')[1]
    arguments = resource[:arguments]
    if arguments.nil?
      arguments = {}
    end
    rabbitmqadmin('declare',
      'binding',
      vhost_opt,
      "--user=#{resource[:user]}",
      "--password=#{resource[:password]}",
      '-c',
      '/etc/rabbitmq/rabbitmqadmin.conf',
      "source=#{name}",
      "destination=#{destination}",
      "arguments=#{arguments.to_json}",
      "routing_key=#{resource[:routing_key]}",
      "destination_type=#{resource[:destination_type]}"
    )
    @property_hash[:ensure] = :present
  end

  def destroy
    vhost_opt = should_vhost ? "--vhost=#{should_vhost}" : ''
    name = resource[:name].split('@').first
    destination = resource[:name].split('@')[1]
    rabbitmqadmin('delete', 'binding', vhost_opt, "--user=#{resource[:user]}", "--password=#{resource[:password]}", '-c', '/etc/rabbitmq/rabbitmqadmin.conf', "source=#{name}", "destination_type=#{resource[:destination_type]}", "destination=#{destination}", "properties_key=#{resource[:routing_key]}")
    @property_hash[:ensure] = :absent
  end

end
