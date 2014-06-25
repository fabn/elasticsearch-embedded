require 'timeout'
require 'net/http'
require 'uri'
require 'json'
require 'logger'

module Elasticsearch
  module Embedded

    # Class used to manage a local cluster of elasticsearch nodes
    class Cluster

      # Logger instance to output messages
      def logger
        @logger ||= Logger.new(STDOUT).tap do |l|
          l.level = Logger::INFO
        end
      end

      # Options for cluster
      attr_accessor :port, :cluster_name, :nodes, :timeout, :persistent, :additional_options

      # Options for downloader
      attr_accessor :downloader, :version, :working_dir

      # Runtime variables
      attr_reader :pids

      # Assign default values to options
      def initialize
        @nodes = 1
        @port = 9250
        @version = Downloader::DEFAULT_VERSION
        @working_dir = Downloader::TEMPORARY_PATH
        @timeout = 30
        @cluster_name = 'elasticsearch_test'
        @pids = []
      end

      # Start an elasticsearch cluster and return immediately
      def start
        @downloader = Downloader.download(version: version, path: working_dir)
        start_cluster
        apply_development_template! if persistent
      end

      # Start an elasticsearch cluster and wait until running, also register
      # a signal handler to close the cluster on INT, TERM and QUIT signals
      def start_and_wait!
        start # start the cluster
        register_shutdown_handler
        # Wait for all child processes to end then return
        Process.waitall
      end

      # Stop the cluster and return after all child processes are dead
      def stop
        begin
          # Try to shutdown cluster using shutdown api
          http_object.post('/_shutdown', nil)
          Timeout.timeout(2) { Process.waitall }
        rescue
          # Send term signal if post request fails to all processes still alive after 2 seconds
          (pids + nodes_pids).each { |pid| wait_or_kill(pid) }
        ensure
          # Reset running pids reader
          @pids = []
        end
      end

      # Return running instances pids, borrowed from code in Elasticsearch::Extensions::Test::Cluster.
      # This method returns elasticsearch nodes pids and not spawned command pids, they are different because of
      # elasticsearch shell wrapper used to launch the daemon
      def nodes_pids
        # Try to fetch node info from running cluster
        nodes = JSON.parse(http_object.get('/_nodes/?process').body) rescue []
        # Fetch pids from returned data
        nodes.empty? ? nodes : nodes['nodes'].map { |_, info| info['process']['id'] }
      end

      # Start server unless it's running
      def ensure_started!
        start unless running?
      end

      # Returns true when started cluster is running
      #
      # @return Boolean
      def running?
        cluster_health = Timeout::timeout(0.25) { __get_cluster_health } rescue nil
        # Response is present, cluster name is the same and number of nodes is the same
        !!cluster_health && cluster_health['cluster_name'] == cluster_name && cluster_health['number_of_nodes'] == nodes
      end

      # Remove all indices in the cluster
      #
      # @return [Array<Net::HTTPResponse>] raw http responses
      def delete_all_indices!
        delete_index! :_all
      end

      # Remove the indices given as args
      #
      # @param [Array<String,Symbol>] args list of indices to delet
      # @return [Array<Net::HTTPResponse>] raw http responses
      def delete_index!(*args)
        args.map { |index| http_object.request(Net::HTTP::Delete.new("/#{index}")) }
      end

      # Used for persistent clusters, otherwise cluster won't get green state because of missing replicas
      def apply_development_template!
        development_settings = {
            template: '*',
            settings: {
                number_of_shards: 1,
                number_of_replicas: 0,
            }
        }
        # Create the template on cluster
        http_object.put('/_template/development_template', JSON.dump(development_settings))
      end

      # Configure class logger verbosity
      # @param [String,Fixnum] level accepts strings levels or numbers
      def verbosity(level)
        case level.to_s
          when /\A\d\Z/
            logger.level = level.to_i
          when /\A(#{%w(DEBUG INFO WARN ERROR FATAL).join('|')})\Z/i
            logger.level = Logger.const_get(level.to_s.upcase)
          else
            logger.level = Logger::INFO
        end
      end

      private

      # Build command line to launch an instance
      def build_command_line(instance_number)
        [
            downloader.executable,
            '-D es.foreground=yes',
            "-D es.cluster.name=#{cluster_name}",
            "-D es.node.name=node-#{instance_number}",
            "-D es.http.port=#{port + (instance_number - 1)}",
            "-D es.gateway.type=#{cluster_options[:gateway_type]}",
            "-D es.index.store.type=#{cluster_options[:index_store]}",
            "-D es.path.data=#{cluster_options[:path_data]}-#{instance_number}",
            "-D es.path.work=#{cluster_options[:path_work]}-#{instance_number}",
            '-D es.network.host=0.0.0.0',
            '-D es.discovery.zen.ping.multicast.enabled=true',
            '-D es.script.disable_dynamic=false',
            '-D es.node.test=true',
            '-D es.node.bench=true',
            additional_options,
            '> /dev/null' # TODO make cluster output optin
        ].compact.join(' ')
      end

      # Spawn an elasticsearch process and return its pid
      def launch_instance(instance_number = 1)
        # Start the process within a new process group to avoid signal propagation
        Process.spawn(build_command_line(instance_number), pgroup: true).tap { |pid| Process.detach pid }
      end

      def start_cluster
        logger.info "Starting ES #{version} cluster with working directory set to #{working_dir}. Process pid is #{$$}"
        if running?
          logger.debug "Elasticsearch cluster already running on port #{port}"
          wait_for_green(timeout)
          return false
        end
        # Launch single node instances
        @pids = 1.upto(nodes).map { |i| launch_instance(i) }
        # Check for proceses running
        if `ps -p #{pids.join(' ')}`.split("\n").size < nodes + 1
          STDERR.puts '', '[!!!] Process failed to start (see output above)'
          exit(1)
        end
        wait_for_green(timeout)
        true
      end

      def wait_or_kill(pid)
        begin
          Timeout::timeout(2) do
            Process.kill(:TERM, pid)
            Process.waitpid(pid)
          end
        rescue Errno::ESRCH, Errno::ECHILD
          # No such process or no child => process is already dead
        rescue Timeout::Error
          # Process still running after 2 seconds of waitpid sending kill to it
          Process.kill(:KILL, pid) rescue nil
        end
      end

      # Used as arguments for building command line to launch elasticsearch
      def cluster_options
        {
            port: port,
            nodes: nodes,
            cluster_name: cluster_name,
            timeout: timeout,
            # command to run is taken from downloader object
            command: downloader.executable,
            # persistency options
            gateway_type: persistent ? 'local' : 'none',
            index_store: persistent ? 'mmapfs' : 'memory',
            path_data: File.join(persistent ? downloader.working_dir : Dir.tmpdir, 'cluster_data'),
            path_work: File.join(persistent ? downloader.working_dir : Dir.tmpdir, 'cluster_workdir'),
        }
      end

      # Return an http object to make requests
      def http_object
        @http ||= Net::HTTP.new('localhost', port)
      end

      # Register a shutdown proc which handles INT, TERM and QUIT signals
      def register_shutdown_handler
        # Stop cluster on Ctrl+C, TERM (foreman) or QUIT (other)
        [:TERM, :INT, :QUIT].each { |sig| Signal.trap(sig, lambda { stop }) }
      end

      # Waits until the cluster is green and prints information
      #
      # @example Print the information about the default cluster
      #     Elasticsearch::Extensions::Test::Cluster.wait_for_green
      #
      # @param (see #__wait_for_status)
      #
      # @return Boolean
      #
      def wait_for_green(timeout = 60)
        __wait_for_status('green', timeout)
      end

      # Blocks the process and waits for the cluster to be in a "green" state.
      #
      # Prints information about the cluster on STDOUT if the cluster is available.
      #
      # @param status  [String]  The status to wait for (yellow, green)
      # @param timeout [Integer] The explicit timeout for the operation
      #
      # @api private
      #
      # @return Boolean
      #
      def __wait_for_status(status='green', timeout = 30)
        Timeout::timeout(timeout) do
          loop do
            response = begin
              JSON.parse(http_object.get("/_cluster/health?wait_for_status=#{status}").body)
            rescue Exception => e
              logger.debug e.inspect if ENV['DEBUG']
              nil
            end

            if response && response['status'] == status && (nodes.nil? || nodes == response['number_of_nodes'].to_i)
              __print_cluster_info and break
            end

            print '.'
            sleep 1
          end
        end

        true
      end

      # Print information about the cluster on STDOUT
      #
      # @api private
      #
      def __print_cluster_info
        health = JSON.parse(http_object.get('/_cluster/health').body)
        nodes = JSON.parse(http_object.get('/_nodes/process,http').body)
        master = JSON.parse(http_object.get('/_cluster/state').body)['master_node']

        puts "\n",
             ('-'*80),
             'Cluster: '.ljust(20) + health['cluster_name'].to_s,
             'Status:  '.ljust(20) + health['status'].to_s,
             'Nodes:   '.ljust(20) + health['number_of_nodes'].to_s

        nodes['nodes'].each do |id, info|
          m = id == master ? '+' : '-'
          puts ''.ljust(20) +
                   "#{m} #{info['name']} | version: #{info['version']}, pid: #{info['process']['id']}, address: #{info['http']['bound_address']}"
        end
      end

      # Tries to load cluster health information
      #
      # @api private
      #
      def __get_cluster_health
        JSON.parse(http_object.get('/_cluster/health').body) rescue nil
      end

    end

  end
end
