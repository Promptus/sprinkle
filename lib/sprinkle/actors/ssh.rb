require 'net/ssh/gateway'
require 'net/scp'

module Sprinkle
  module Actors
    # The SSH actor requires no additional deployment tools other than the 
    # Ruby SSH libraries.
    #
    #   deployment do
    #     delivery :ssh do
    #       user "rails"
    #       password "leetz"
    #
    #       role :app, "app.myserver.com"
    #     end
    #   end
    #
    #
    # == Use ssh key file
    #
    #   deployment do
    #     delivery :ssh do
    #       user "sprinkle"
    #       keys "/path/to/ssh/key/file" # passed directly to Net::SSH as :keys option
    #
    #       role :app, "app.myserver.com"
    #     end
    #   end
    #
    #
    # == Working thru a gateway
    #
    # If you're behind a firewall and need to use a SSH gateway that's fine.
    # 
    #   deployment do
    #     delivery :ssh do
    #       gateway "work.sshgateway.com"
    #     end
    #   end
    class SSH < Actor
      attr_accessor :options #:nodoc:
      
      class SSHCommandFailure < StandardError #:nodoc:
        attr_accessor :details
      end
      
      class SSHConnectionCache
        def initialize; @cache={}; end
        def start(host, user, opts={})
          key="#{host}#{user}#{opts.to_s}"
          @cache[key] ||= Net::SSH.start(host,user,opts)
        end
      end
      
      
      def initialize(options = {}, &block) #:nodoc:
        @options = options.update(:user => 'root')
        @roles = {}
        @connection_cache = SSHConnectionCache.new
        self.instance_eval &block if block
        raise "You must define at least a single role." if @roles.empty?
      end

      # Define a whole host of roles at once
      #
      # This is depreciated - you should be using role instead.
      def roles(roles)
        @roles = roles
      end
      
      # Determines if there are any servers for the given roles
      def servers_for_role?(roles)
        roles=Array(roles)
        roles.any? { |r| @roles.keys.include? (r) }
      end

      # Define a role and add servers to it
      #   
      #   role :app, "app.server.com"
      #   role :db, "db.server.com"
      def role(role, server)
        @roles[role] ||= []
        @roles[role] << server
      end
      
      # Set an optional SSH gateway server - if set all outbound SSH traffic
      # will go thru this gateway
      def gateway(gateway)
        @options[:gateway] = gateway
      end
      
      # Set the SSH user
      def user(user)
        @options[:user] = user
      end

      # Set the SSH password
      def password(password)
        @options[:password] = password
      end

      def keys(keys)
        @options[:keys] = keys
      end

      # Set this to true to prepend 'sudo' to every command.
      def use_sudo(value=true)
        @options[:use_sudo] = value
      end
      
      def sudo?
        @options[:use_sudo]
      end
      
      def sudo_command
        "sudo"
      end

      def setup_gateway #:nodoc:
        @gateway ||= Net::SSH::Gateway.new(@options[:gateway], @options[:user]) if @options[:gateway]
      end
      
      def teardown #:nodoc:
        @gateway.shutdown! if @gateway
      end
      
      def verify(verifier, roles, opts = {}) #:nodoc:
        @verifier = verifier
        # issue all the verification steps in a single SSH command
        commands=[verifier.commands.join(" && ")]
        process(verifier.package.name, commands, roles)
      rescue SSHCommandFailure => e
        false
      ensure
        @verifier = nil
      end
      
      def install(installer, roles, opts = {}) #:nodoc:
        @installer = installer
        process(installer.package.name, installer.install_sequence, roles)
      rescue SSHCommandFailure => e
        raise_error(e)
      ensure
        @installer = nil
      end

      protected
      
        def raise_error(e)
          raise Sprinkle::Errors::RemoteCommandFailure.new(@installer, e.details, e)
        end
      
        def process(name, commands, roles, opts = {}) #:nodoc:
          setup_gateway
          r=execute_on_role(commands, roles)
          logger.debug green "process returning #{r}"
          return r
        end      
      
        def execute_on_role(commands, role) #:nodoc:
          hosts = @roles[role]
          Array(hosts).each do |host| 
            success = execute_on_host(commands, host)
            return false unless success
          end
        end
        
        def prepare_commands(commands)
          return commands unless sudo?
          commands.map do |command| 
            next command if command.is_a?(Symbol)
            command.match(/^#{sudo_command}/) ? command : "#{sudo_command} #{command}"
          end
        end
        
        def execute_on_host(commands,host) #:nodoc:
          session = ssh_session(host)
          @log_recorder = Sprinkle::Utility::LogRecorder.new
          prepare_commands(commands).each do |cmd|
            if cmd == :TRANSFER
              transfer_to_host(@installer.sourcepath, @installer.destination, session, 
                :recursive => @installer.options[:recursive])
              next
            elsif cmd == :RECONNECT
              session.close # disconnenct
              session = ssh_session(host) # reconnect
              next
            end
            @log_recorder.reset cmd
            res = ssh(session, cmd)
            if res != 0 
              fail=SSHCommandFailure.new
              fail.details = @log_recorder.hash.merge(:hosts => host)
              raise fail
            end
          end
          true
        end
        
        def ssh(host, cmd, opts={}) #:nodoc:
          session = host.is_a?(Net::SSH::Connection::Session) ? host : ssh_session(host)
          logger.debug "[#{session.host}] ssh: #{cmd}"
          channel_runner(session, cmd)
        end
        
        def channel_runner(session, command) #:nodoc:
          session.open_channel do |channel|
            channel.on_data do |ch, data|
              @log_recorder.log :out, data
              logger.debug yellow("[#{session.host}] stdout said-->\n#{data}\n")
            end
            channel.on_extended_data do |ch, type, data|
              next unless type == 1  # only handle stderr
              @log_recorder.log :err, data
              logger.debug red("[#{session.host}] stderr said -->\n#{data}\n")
            end

            channel.on_request("exit-status") do |ch, data|
              @log_recorder.code = data.read_long
              if @log_recorder.code == 0
                logger.debug(green 'success')
              else
                logger.debug(red('failed (%d).' % @log_recorder.code))
              end
            end

            channel.on_request("exit-signal") do |ch, data|
              logger.debug red("#{cmd} was signaled!: #{data.read_long}")
            end

            channel.exec command  do  |ch, status|
              logger.error("couldn't run remote command #{cmd}") unless status
              @log_recorder.code = -1
            end
          end
          session.loop
          @log_recorder.code
        end
        
        def transfer_to_role(source, destination, role, opts={}) #:nodoc:
          hosts = @roles[role]
          Array(hosts).each { |host| transfer_to_host(source, destination, host, opts) }
        end
        
        def transfer_to_host(source, destination, host, opts={}) #:nodoc:
          logger.debug "upload: #{destination}"
          session = host.is_a?(Net::SSH::Connection::Session) ? host : ssh_session(host)
          scp = Net::SCP.new(session)
          scp.upload! source, destination, :recursive => opts[:recursive], :chunk_size => 32.kilobytes
        rescue RuntimeError => e
          if e.message =~ /Permission denied/
            raise TransferFailure.no_permission(@installer,e)
          else
            raise e
          end          
        end
        
        def ssh_session(host)
          if @gateway
            gateway.ssh(host, @options[:user])
          else
            @connection_cache.start(host, @options[:user],:password => @options[:password], :keys => @options[:keys])
          end
        end        
        
        private
        def color(code, s)
          "\033[%sm%s\033[0m"%[code,s]
        end
        def red(s)
          color(31, s)
        end
        def yellow(s)
          color(33, s)
        end
        def green(s)
          color(32, s)
        end
        def blue(s)
          color(34, s)
        end
    end
  end
end
