require 'elasticsearch/embedded/version'
require 'elasticsearch/embedded/logger_configuration'

module Elasticsearch
  module Embedded

    autoload :Downloader, 'elasticsearch/embedded/downloader'
    autoload :Cluster, 'elasticsearch/embedded/cluster'
    autoload :RSpec, 'elasticsearch/embedded/rspec_configuration'

    # Configure logging for this module
    extend LoggerConfiguration

  end
end
