require 'logging'

module Elasticsearch
  module Embedded

    # Contains stuff related to logging configuration
    module LoggerConfiguration

      # Configure logger verbosity for ::Elasticsearch::Embedded log hierarchy
      # @param [String,Fixnum] level accepts strings levels or numbers
      def verbosity(level)
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
      def mute!
        Logging.logger[self].clear_appenders
      end

      # @see https://github.com/TwP/logging/blob/master/examples/colorization.rb
      def configure_logging!
        # Configure logger levels for hierarchy
        Logging.logger[self].level = :info
        # Register a color scheme named bright
        Logging.color_scheme 'bright', {
            levels: {
                info: :green,
                warn: :yellow,
                error: :red,
                fatal: [:white, :on_red]
            },
            date: :blue,
            logger: :cyan,
            message: :white,
        }
        pattern_options = {pattern: '[%d] %-5l %c: %m\n'}
        # Apply colors only if in tty
        pattern_options[:color_scheme] = 'bright' if STDOUT.tty?
        # Create a named appender to be used only for current module
        Logging.logger[self].appenders = Logging.appenders.stdout(self.to_s, layout: Logging.layouts.pattern(pattern_options))
      end

      private

      # Extension callback
      def self.extended(base)
        base.configure_logging!
      end

    end

  end
end
