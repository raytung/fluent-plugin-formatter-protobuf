# frozen_string_literal: true

#
# Copyright 2021-Ray Tung
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fluent/plugin/formatter'

require 'pathname'
require 'google/protobuf'

require 'fluent/env'
require 'fluent/time'

module Fluent
  module Plugin
    # ProtobufFormatter for Fluentd
    class ProtobufFormatter < Fluent::Plugin::Formatter
      Fluent::Plugin.register_formatter('protobuf', self)

      # Absolute paths to the generated Ruby protobuf files
      config_param :include_paths, :array, default: []

      # Protobuf message name
      config_param :class_name, :string

      def configure(conf)
        super(conf)

        raise Fluent::ConfigError, "Missing 'include_paths'" if @include_paths.empty?

        @include_paths.each { |path| require_proto!(path) } unless @include_paths.empty?

        class_lookup = Google::Protobuf::DescriptorPool.generated_pool.lookup(@class_name)
        raise Fluent::ConfigError, "class name '#{@class_name}' not found" if class_lookup.nil?

        @protobuf_class = class_lookup.msgclass
      end

      def formatter_type
        :binary
      end

      def format(_tag, _time, record)
        protobuf_msg = @protobuf_class.new(record)
        @protobuf_class.encode(protobuf_msg)
      end

      def require_proto!(filename)
        if Pathname.new(filename).absolute?
          require filename
        else
          require_relative filename
        end
      rescue LoadError => e
        raise Fluent::ConfigError, "Unable to load file '#{filename}'. Reason: #{e.inspect}"
      end
    end
  end
end
