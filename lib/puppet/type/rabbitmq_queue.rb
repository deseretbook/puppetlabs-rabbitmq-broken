Puppet::Type.newtype(:rabbitmq_queue) do
  desc 'Native type for managing rabbitmq queues'

  ensurable do
    defaultto(:present)
    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.destroy
    end
  end

  newparam(:name) do
    desc 'Name set to title. Completely unused. See unique name'
    defaultto('DEFAULT_NAME')
  end

  newparam(:vhost) do
    desc 'Vhost of queue. Defaults to /. Set *on creation*'
    defaultto('/')
  end

  newparam(:queue_name) do
    desc 'Name of queue. Set *on creation*'
  end

  newparam(:unique_name) do
    desc 'Unique name of queue. It is built on the fly from other fields!'
    defaultto('DEFAULT_NAME')

    validate do |unique_name|
      unless unique_name == 'DEFAULT_NAME'
        raise ArgumentError, 'unique_name field should not be populated in manifest - it is built on the fly from other fields!'
      end
    end

    munge do |unique_name|
      unique_name = resource[:queue_name] + '@' + resource[:vhost]
    end
  end

  newparam(:durable) do
    desc 'Queue is durable'
    newvalues(/true|false/)
    defaultto('true')
  end
  
  newparam(:auto_delete) do
    desc 'Queue will be auto deleted'
    newvalues(/true|false/)
    defaultto('false')
  end

  newparam(:arguments) do
    desc 'Queue arguments example: {x-message-ttl => 60, x-expires => 10}'
    defaultto {}
    validate do |value|
      resource.validate_argument(value)
    end
  end

  newparam(:user) do
    desc 'The user to use to connect to rabbitmq'
    defaultto('guest')
    newvalues(/^\S+$/)
  end

  newparam(:password) do
    desc 'The password to use to connect to rabbitmq'
    defaultto('guest')
    newvalues(/\S+/)
  end

  autorequire(:rabbitmq_vhost) do
    [self[:name].split('@')[1]]
  end

  autorequire(:rabbitmq_user) do
    [self[:user]]
  end

  autorequire(:rabbitmq_user_permissions) do
    ["#{self[:user]}@#{self[:name].split('@')[1]}"]
  end

  def validate_argument(argument)
    unless [Hash].include?(argument.class)
      raise ArgumentError, "Invalid argument"
    end
  end
end
