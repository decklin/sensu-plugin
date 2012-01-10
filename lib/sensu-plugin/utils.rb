module Sensu
  module Plugin
    module Utils

      # Unfortunately, we need to reimplement config loading. This is not a
      # great way to override paths but we don't want to occupy any command
      # line options.

      def config_files
        if ENV['SENSU_CONFIG_FILES']
          ENV['SENSU_CONFIG_FILES'].split(':')
        else
          config_file = ENV['SENSU_CONFIG'] || '/etc/sensu/config.json'
          config_dir = ENV['SENSU_CONF_D'] || '/etc/sensu/conf.d'
          [config_file] + Dir[File.join(config_dir, '*.json')].sort
        end
      end

      def load_config(filename)
        JSON.parse(File.open(filename, 'r').read) rescue Hash.new
      end

      def settings
        @settings ||= config_files.map {|f| load_config(f) }.reduce {|a, b| a.deep_merge(b) }
      end

      def read_event(file)
        begin
          @event = ::JSON.parse(file.read)
          @event['occurrences'] ||= 1
          @event['check']       ||= Hash.new
          @event['client']      ||= Hash.new
        rescue => e
          puts 'error reading event: ' + e.message
          exit 0
        end
      end

      def net_http_req_class(method)
        case method.to_s.upcase
        when 'GET'
          Net::HTTP::Get
        when 'POST'
          Net::HTTP::Post
        when 'DELETE'
          Net::HTTP::Delete
        when 'PUT'
          Net::HTTP::Put
        end
      end
    end
  end
end

# Monkey Patching.

class Array
  def deep_merge(other_array, &merger)
    concat(other_array).uniq
  end
end

class Hash
  def deep_merge(other_hash, &merger)
    merger ||= proc do |key, old_value, new_value|
      old_value.deep_merge(new_value, &merger) rescue new_value
    end
    merge(other_hash, &merger)
  end
end
