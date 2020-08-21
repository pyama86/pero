module Pero
  class Puppet
    class Base
      attr_reader :specinfra, :os_info
      def initialize(specinfra, os)
        @specinfra = specinfra
        @os_info = os
      end

      def run_specinfra(type, *args)
        command = specinfra.command.get(type, *args)
        if type.to_s.start_with?("check_")
          check_command(command)
        else
          specinfra.run_command(command)
        end
      end

      def check_command(*args)
        unless args.last.is_a?(Hash)
          args << {}
        end
        specinfra.run_command(*args).exit_status == 0
      end

    end
  end
end
