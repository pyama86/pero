require 'json'
require "fileutils"
module Pero
  class History
    def self.search(query, dir="nodes")
      ret = []
      Dir.foreach(dir) do |f|
        next if %w(. ..).include? f
        next unless f =~ /json$/
        File.open(File.join(dir, f)) do |j|
          h = JSON.load(j)
          ret << h if h["name"] =~ /#{query}/
        end
      end
      ret
    end
  end
end

module Pero
  class History
    class Attribute
      def initialize(specinfra, options)
        name = if options["node-name"].empty?
                 specinfra.run_command("hostname").stdout.chomp
               else
                 options["node-name"]
               end
        options.delete("noop")
        options.delete("tags")
        @h = {
          name: name,
          last_options: options
        }
      end

      def save(dir="nodes")
        FileUtils.mkdir_p(dir)
        File.write("#{File.join(dir, @h[:name])}.json", @h.to_json)
      end
    end
  end
end
