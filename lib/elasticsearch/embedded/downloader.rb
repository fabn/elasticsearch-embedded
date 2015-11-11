# coding: utf-8
require 'tmpdir'
require 'open-uri'
require 'ruby-progressbar'
require 'zip'

module Elasticsearch
  module Embedded
    class Downloader

      # Default temporary path used by downloader
      TEMPORARY_PATH = defined?(::Rails) ? ::Rails.root.join('tmp') : Dir.tmpdir
      # Default version of elasticsearch to download
      DEFAULT_VERSION = '1.4.0'

      attr_reader :version, :path

      def initialize(args = {})
        @version = args[:version] || ENV['ELASTICSEARCH_VERSION'] || DEFAULT_VERSION
        @path = args[:path] || ENV['ELASTICSEARCH_DOWNLOAD_PATH'] || TEMPORARY_PATH
      end

      # Download elasticsearch distribution and unzip it in the specified temporary path
      def self.download(arguments = {})
        new(arguments).perform
      end

      def perform
        download_file
        extract_file
        self
      end

      def downloaded?
        File.exists?(final_path)
      end

      def extracted?
        File.directory?(dist_folder)
      end

      def dist_folder
        @dist_folder ||= final_path.gsub /\.zip\Z/, ''
      end

      def final_path
        @final_path ||= File.join(working_dir, "elasticsearch-#{version}.zip")
      end

      def working_dir
        @working_dir ||= File.realpath(path)
      end

      def executable
        @executable ||= File.join(dist_folder, 'bin', 'elasticsearch')
      end

      private

      def download_file
        return if downloaded?
        open(final_path, 'wb') do |target|
          download_options = {
              content_length_proc: ->(t) { build_progress_bar(t) },
              progress_proc: ->(s) { increment_progress(s) }
          }
          # direct call here to avoid spec issues with Kernel#open
          distfile = OpenURI.open_uri("https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-#{version}.zip", download_options)
          target << distfile.read
        end
      end

      def extract_file
        return if extracted?
        Dir.chdir(working_dir) do
          # Extract archive in path, after block CWD is restored
          Zip::File.open(final_path) do |zip_file|
            # Extract all entries into working dir
            zip_file.each(&:extract)
          end
        end
        # ensure main executable has execute permission
        File.chmod(0755, executable)
        # Create folder for log files
        FileUtils.mkdir(File.join(dist_folder, 'logs'))
      end

      # Build a progress bar to download elasticsearch
      def build_progress_bar(total)
        if total && total.to_i > 0
          @download_progress_bar = ProgressBar.create title: "Downloading elasticsearch #{version}", total: total,
                                                      format: '%t |%bᗧ%i| %p%% (%r KB/sec) %e', progress_mark: ' ', remainder_mark: '･',
                                                      rate_scale: ->(rate) { rate / 1024 }, smoothing: 0.7
        end
      end

      def increment_progress(size)
        @download_progress_bar.progress = size if @download_progress_bar
      end

    end

  end
end
