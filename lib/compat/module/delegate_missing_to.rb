if !Module.public_instance_methods.include?(:delegate_missing_to)
  require 'active_support/core_ext/module/delegation'

  class Module
    # When building decorators, a common pattern may emerge:
    #
    #   class Partition
    #     def initialize(event)
    #       @event = event
    #     end
    #
    #     def person
    #       @event.detail.person || @event.creator
    #     end
    #
    #     private
    #       def respond_to_missing?(name, include_private = false)
    #         @event.respond_to?(name, include_private)
    #       end
    #
    #       def method_missing(method, *args, &block)
    #         @event.send(method, *args, &block)
    #       end
    #   end
    #
    # With <tt>Module#delegate_missing_to</tt>, the above is condensed to:
    #
    #   class Partition
    #     delegate_missing_to :@event
    #
    #     def initialize(event)
    #       @event = event
    #     end
    #
    #     def person
    #       @event.detail.person || @event.creator
    #     end
    #   end
    #
    # The target can be anything callable within the object, e.g. instance
    # variables, methods, constants, etc.
    #
    # The delegated method must be public on the target, otherwise it will
    # raise +NoMethodError+.
    def delegate_missing_to(target)
      target = target.to_s
      target = "self.#{target}" if DELEGATION_RESERVED_METHOD_NAMES.include?(target)

      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def respond_to_missing?(name, include_private = false)
          # It may look like an oversight, but we deliberately do not pass
          # +include_private+, because they do not get delegated.

          #{target}.respond_to?(name) || super
        end

        def method_missing(method, *args, &block)
          if #{target}.respond_to?(method)
            #{target}.public_send(method, *args, &block)
          else
            begin
              super
            rescue NoMethodError
              if #{target}.nil?
                raise DelegationError, "\#{method} delegated to #{target}, but #{target} is nil"
              else
                raise
              end
            end
          end
        end
      RUBY
    end
  end
end
