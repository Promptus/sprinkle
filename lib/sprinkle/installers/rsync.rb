module Sprinkle
  module Installers
    class RSync < Installer
      
      attr_accessor :source, :destination
      
      def initialize(parent, source, destination, options, &block)
        super parent, &block
        @source = source
        @destination = destination
      end
      
      protected 
      
      def process(roles)
        if logger.debug?
          logger.debug "rsync: #{@source} -> #{@destination} for roles: #{roles}\n"
        end
        rsync_options = ['-ltp']
        rsync_options << '-r' if options[:recursive]
        rsync_options << "--rsync-path='sudo rsync'"
        roles.each do |role|
          system "rsync #{rsync_options.join(' ')} #{source} #{role}:#{destination}"
        end
      end
      
    end
  end
end
