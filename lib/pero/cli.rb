require "pero"
require "thor"

module Pero
  class CLI < Thor
    desc "", ""
    def apply
      image = Pero::Puppet::Docker.build("3.3.1")
      Pero::Puppet::Docker.run(image)
    end

  end
end
