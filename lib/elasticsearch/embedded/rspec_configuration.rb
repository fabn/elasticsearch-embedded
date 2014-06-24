module Elasticsearch
  module Embedded

    module RSpec

      module ElasticSearchHelpers
        # Return a client connected to the configured client, if ::Elasticsearch::Client is defined
        # return a client, else return a URI attached to cluster.
        # @see http://ruby-doc.org/stdlib-2.1.2/libdoc/net/http/rdoc/Net/HTTP.html
        # @see https://github.com/elasticsearch/elasticsearch-ruby
        def client
          @client ||=
              case
                when defined?(::Elasticsearch::Client)
                  puts "Port is #{cluster.port}"
                  ::Elasticsearch::Client.new host: "localhost:#{cluster.port}"
                else
                  URI("http://localhost:#{cluster.port}/")
              end
        end

        # Return a cluster instance to be used in tests
        def cluster
          ElasticSearchHelpers.memoized_cluster
        end

        class << self

          # Return a singleton instance of cluster object
          def memoized_cluster
            @cluster ||= ::Elasticsearch::Embedded::Cluster.new
          end

        end

      end

      class << self

        # Configure rspec for usage with ES cluster
        def configure_with(*meta)
          # assign default value to tags
          ::RSpec.configure do |config|

            # Include helpers only in tagged specs
            config.include ElasticSearchHelpers, *meta

            # Before hook, starts the cluster
            config.before(:each, *meta) do
              ElasticSearchHelpers.memoized_cluster.ensure_started!
              ElasticSearchHelpers.memoized_cluster.delete_all_indices!
            end

            # After suite hook, stop the cluster
            config.after(:suite) do
              ElasticSearchHelpers.memoized_cluster.stop if ElasticSearchHelpers.memoized_cluster.running?
            end
          end
        end

        # Default config method, configure RSpec with :elasticsearch filter only.
        # Equivalent to .configure_with(:elasticsearch)
        def configure
          configure_with(:elasticsearch)
        end
      end

    end

  end
end
