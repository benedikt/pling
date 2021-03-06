require 'faraday'

module Pling
  module C2DM
    ##
    # Pling gateway to communicate with Google's Android C2DM service.
    #
    # The gateway is implemented using Faraday. It defaults to Faraday's :net_http adapter.
    # You can customize the adapter by passing the :adapter configuration.
    #
    # @example
    #
    #   Pling::C2DM::Gateway.new({
    #     :email    => 'your-email@gmail.com', # Your google account's email address (Required)
    #     :password => 'your-password',        # Your google account's password (Required)
    #     :source   => 'your-app-name',        # Your applications source identifier (Required)
    #
    #     :authentication_url => 'http://...', # The authentication url to use (Optional, Default: C2DM default authentication url)
    #     :push_url           => 'http://...', # The push url to use (Optional, Default: C2DM default authentication url)
    #     :adapter            => :net_http,    # The Faraday adapter you want to use (Optional, Default: :net_http)
    #     :connection         => {}            # Options you want to pass to Faraday (Optional, Default: {})
    #   })
    class Gateway < Pling::Gateway

      handles :android, :c2dm

      attr_reader :token

      ##
      # Initializes a new gateway to Apple's Push Notification service
      #
      # @param [Hash] configuration
      # @option configuration [String] :email Your C2DM enabled Google account (Required)
      # @option configuration [String] :password Your Google account's password (Required)
      # @option configuration [String] :source Your applications identifier (Required)
      # @option configuration [String] :authentication_url The URL to authenticate with (Optional)
      # @option configuration [String] :push_url The URL to push to (Optional)
      # @option configuration [Symbol] :adapter The Faraday adapter to use (Optional)
      # @option configuration [String] :connection Any options for Faraday (Optional)
      # @raise Pling::AuthenticationFailed
      def initialize(configuration)
        super
        require_configuration([:email, :password, :source])
        setup!
      end

      def setup!
        authenticate! unless token
      end

      ##
      # Sends the given message to the given device.
      #
      # @param [#to_pling_message] message
      # @param [#to_pling_device] device
      # @raise Pling::DeliveryFailed
      def deliver!(message, device)
        data = {
          :registration_id => device.identifier,
          :'data.body'  => message.body,
          :'data.badge' => message.badge,
          :'data.sound' => message.sound,
          :'data.subject' => message.subject,
          :collapse_key => message.body.hash
        }.delete_if { |_, value| value.nil? }

        if configuration[:payload] && message.payload
          message.payload.each do |key, value|
            data["data.#{key}".to_sym] = value
          end
        end

        response = connection.post(configuration[:push_url], data, { :Authorization => "GoogleLogin auth=#{@token}"})

        if !response.success? || response.body =~ /^Error=(.+)$/
          error_class = Pling::C2DM.const_get($1) rescue Pling::DeliveryFailed
          raise error_class.new("C2DM Delivery failed: [#{response.status}] #{response.body}", message, device)
        end
      end

      private

        def authenticate!
          response = connection.post(configuration[:authentication_url], {
            :accountType => 'HOSTED_OR_GOOGLE',
            :service     => 'ac2dm',
            :Email       => configuration[:email],
            :Passwd      => configuration[:password],
            :source      => configuration[:source]
          })

          raise(Pling::AuthenticationFailed, "C2DM Authentication failed: [#{response.status}] #{response.body}") unless response.success?

          @token = extract_token(response.body)
        end

        def default_configuration
          super.merge({
            :authentication_url => 'https://www.google.com/accounts/ClientLogin',
            :push_url           => 'https://android.apis.google.com/c2dm/send',
            :adapter            => :net_http,
            :connection         => {}
          })
        end

        def connection
          Faraday.new(configuration[:connection]) do |builder|
            builder.use Faraday::Request::UrlEncoded
            builder.use Faraday::Response::Logger if configuration[:debug]
            builder.adapter(configuration[:adapter])
          end
        end

        def extract_token(body)
          matches = body.match(/^Auth=(.+)$/)
          matches ? matches[1] : raise(Pling::AuthenticationFailed, "C2DM Token extraction failed")
        end
    end
  end
end
