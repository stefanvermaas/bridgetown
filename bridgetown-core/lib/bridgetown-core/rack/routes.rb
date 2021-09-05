# frozen_string_literal: true

module Bridgetown
  module Rack
    class Routes
      class << self
        attr_accessor :tracked_subclasses

        def inherited(base)
          Bridgetown::Rack::Routes.track_subclass base
          super
        end

        def track_subclass(klass)
          Bridgetown::Rack::Routes.tracked_subclasses ||= {}
          Bridgetown::Rack::Routes.tracked_subclasses[klass.name] = klass
        end

        def reload_subclasses
          Bridgetown::Rack::Routes.tracked_subclasses.each_key do |klassname|
            Kernel.const_get(klassname)
          rescue NameError
            Bridgetown::Rack::Routes.tracked_subclasses.delete klassname
          end
        end

        attr_accessor :router_block

        def route(&block)
          self.router_block = block
        end

        def merge(roda_app)
          return unless router_block

          new(roda_app).handle_routes
        end

        def start!(roda_app)
          Bridgetown::Rack::Routes.tracked_subclasses.each_value do |klass|
            klass.merge roda_app
          end

          nil
        end
      end

      def initialize(roda_app)
        @roda_app = roda_app
      end

      def handle_routes
        instance_exec(@roda_app.request, &self.class.router_block)
      end

      # rubocop:disable Style/MissingRespondToMissing
      ruby2_keywords def method_missing(method_name, *args, &block)
        if @roda_app.respond_to?(method_name.to_sym)
          @roda_app.send method_name.to_sym, *args, &block
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @roda_app.respond_to?(method_name.to_sym, include_private) || super
      end
      # rubocop:enable Style/MissingRespondToMissing
    end
  end
end