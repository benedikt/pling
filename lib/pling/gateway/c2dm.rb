require 'faraday'

module Pling
  module Gateway
    class C2DM < Pling::Gateway::Base

      attr_reader :token

      def initialize(configuration)
        setup_configuration(configuration, :require => [:email, :password, :source])
        authenticate!
      end

      def deliver(message, device)
        raise "The given object #{message.inspect} does not implement #to_pling_message" unless message.respond_to?(:to_pling_message)
        raise "The given object #{device.inspect} does not implement #to_pling_device"   unless device.respond_to?(:to_pling_device)
        message = message.to_pling_message
        device  = device.to_pling_device
      end

      private

        def authenticate!
          response = connection.post(configuration[:authentication_url], {
            :accountType => 'HOSTED_OR_GOOGLE',
            :service =>     'ac2dm',
            :Email =>       configuration[:email],
            :Passwd =>      configuration[:password],
            :source =>      configuration[:source]
          })

          raise "C2DM Authentication failed: #{response.body}" unless response.success?

          @token = extract_token(response.body)
        end

        def default_configuration
          super.merge({
            :authentication_url => 'https://www.google.com/accounts/ClientLogin',
            :push_url => 'https://android.apis.google.com/c2dm/send',
            :adapter => :net_http,
            :connection => {}
          })
        end

        def connection
          @connection ||= Faraday.new(configuration[:authentication_url]) do |builder|
            builder.use Faraday::Request::UrlEncoded
            builder.adapter(configuration[:adapter])
          end
        end

        def extract_token(body)
          matches = body.match(/^Auth=(.+)$/)
          matches && matches[1] or raise "C2DM Token extraction failed"
        end
    end
  end
end