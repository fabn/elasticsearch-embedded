require 'elasticsearch/embedded/version'

module Elasticsearch
  module Embedded

    autoload :Downloader, 'elasticsearch/embedded/downloader'
    autoload :Cluster, 'elasticsearch/embedded/cluster'
    autoload :RSpec, 'elasticsearch/embedded/rspec_configuration'

  end
end
