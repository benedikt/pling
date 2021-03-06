require 'pling/version'
require 'logger'

module Pling

  autoload :Device,       'pling/device'
  autoload :Message,      'pling/message'
  autoload :Gateway,      'pling/gateway'
  autoload :APN,          'pling/apn'
  autoload :C2DM,         'pling/c2dm'
  autoload :GCM,          'pling/gcm'
  autoload :Middleware,   'pling/middleware'
  autoload :Adapter,      'pling/adapter'
  autoload :Configurable, 'pling/configurable'
  autoload :DelayedInitializer,    'pling/delayed_initializer'

  @gateways = Pling::DelayedInitializer.new
  @middlewares = Pling::DelayedInitializer.new
  @adapter = Pling::Adapter::Base.new
  @logger = Logger.new(nil)

  class Error < StandardError; end
  class AuthenticationFailed < Error; end
  class NoGatewayFound < Error; end

  class DeliveryFailed < Error
    attr_reader :pling_message, :pling_device

    def initialize(message = nil, pling_message = nil, pling_device = nil)
      super(message)
      @pling_message = pling_message
      @pling_device  = pling_device
    end
  end


  class << self
    ##
    # Stores the list of available gateway instances
    #
    # @return [Array] list of available gateways
    attr_reader :gateways

    def gateways=(gateways)
      gateways.each { |gateway| @gateways << gateway }
    end

    ##
    # Stores the list of avaiable middleware instances
    #
    # @return [Array] list of available middleware
    attr_reader :middlewares

    def middlewares=(middlewares)
      middlewares.each { |middleware| @middlewares << middleware }
    end

    ##
    # Stores the adapter
    #
    # @return [Pling::Adapter]
    attr_accessor :adapter

    ##
    # Stores the logger. Defaults to Logger.new(nil)
    #
    # @return [Logger]
    attr_accessor :logger

    ##
    # Allows configuration of Pling by passing a config object to the given block
    #
    # @yield [config]
    # @raise [ArgumentError] Raised when no block is given
    def configure
      raise ArgumentError, 'No block given for Pling.configure' unless block_given?
      yield self
    end

    ##
    # Delivers the given message to the given device using the given stack.
    #
    # @param message [#to_pling_message]
    # @param device [#to_pling_device]
    # @param stack [Array] The stack to use (Default: middlewares + [adapter])
    def deliver(message, device, stack = nil)
      message = Pling._convert(message, :message)
      device  = Pling._convert(device, :device)

      Pling.logger.info "#{self.class} -- Delivering #{message.inspect} to #{device.inspect}"

      stack ||= middlewares.initialize! + [adapter]

      stack.shift.deliver(message, device) do |m, d|
        deliver(m, d, stack)
      end
    end

    ##
    # [INTERNAL METHOD] Converts the given object to the given pling type
    #
    # @private
    # @param object [Object] The object that needs to be converted
    # @param type [Symbol, String] #to_pling_ method suffix
    # @raise [ArgumentError] The object does not implement a #to_pling_ + type method
    def _convert(object, type)
      method = :"to_pling_#{type}"
      raise ArgumentError, "Instances of #{object.class} do not implement ##{method}" unless object.respond_to?(method)
      object && object.send(method)
    end
  end

end
