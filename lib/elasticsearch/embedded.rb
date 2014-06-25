require 'elasticsearch/embedded/version'
require 'logging'

module Elasticsearch
  module Embedded

    autoload :Downloader, 'elasticsearch/embedded/downloader'
    autoload :Cluster, 'elasticsearch/embedded/cluster'
    autoload :RSpec, 'elasticsearch/embedded/rspec_configuration'

    # Configure logger levels for hierarchy
    Logging.logger[self].appenders = Logging.appenders.stdout
    Logging.logger[self].level = :info

    # Configure logger verbosity for ::Elasticsearch::Embedded log hierarchy
    # @param [String,Fixnum] level accepts strings levels or numbers
    def self.verbosity(level)
      level = level.to_s.downcase # normalize string to downcase
      case
        when level =~ /\A\d\Z/
          Logging.logger[self].level = level.to_i
        when Logging::LEVELS.include?(level)
          Logging.logger[self].level = Logging::LEVELS[level]
        else
          Logging.logger[self].level = :info
      end

    end

    # Clear all logging appenders for ::Elasticsearch::Embedded log hierarchy
    def self.mute!
      Logging.logger[self].clear_appenders
    end

  end
end
