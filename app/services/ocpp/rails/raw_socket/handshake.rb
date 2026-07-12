require "cgi"

module Ocpp
  module Rails
    module RawSocket
      # Decides whether a raw OCPP-J WebSocket upgrade should be accepted, purely
      # from the Rack env — no socket I/O — so it is unit-testable in isolation
      # and identical whether the transport hijacks under Puma or is driven by a
      # test harness.
      #
      # OCPP-J carries the charge-point identity in the URL *path* (unlike the
      # ActionCable channel, which reads it from the subscribe command) and the
      # Security-Profile-1 credential in the HTTP Basic `Authorization` header of
      # the upgrade. This mirrors `ChargePointChannel#subscribed` — connection
      # rate limit, then `StationAuthenticator` — so both transports authenticate
      # a station identically.
      class Handshake
        Result = Struct.new(:charge_point, :identifier, :subprotocol, :failure, keyword_init: true) do
          def accepted?
            failure.nil?
          end
        end

        def initialize(env, subprotocols: Ocpp::Rails.configuration.websocket_subprotocols)
          @env = env
          @subprotocols = Array(subprotocols)
        end

        def call
          identifier = self.class.identifier_from_path(@env["PATH_INFO"])
          return reject(identifier, :missing_identifier) if identifier.nil? || identifier.empty?

          unless Ocpp::Rails.connection_rate_limiter.allow?(identifier)
            return reject(identifier, :rate_limited)
          end

          result = StationAuthenticator.authenticate(
            identifier: identifier,
            authorization_header: @env["HTTP_AUTHORIZATION"]
          )
          return reject(identifier, result.failure) unless result.success?

          Result.new(
            charge_point: result.charge_point,
            identifier: identifier,
            subprotocol: negotiated_subprotocol,
            failure: nil
          )
        end

        # The OCPP identity is the last non-empty path segment, URL-decoded:
        # "/ocpp/CP-1" and vendor variants like "/ocpp/steve/CP-1" both yield
        # "CP-1". (Under the mounted engine the endpoint sees the engine-relative
        # path, e.g. "/CP-1".)
        def self.identifier_from_path(path)
          return nil if path.nil?

          segment = path.split("/").reject(&:empty?).last
          segment && CGI.unescape(segment)
        end

        private

        # The actual Sec-WebSocket-Protocol echo is performed by the websocket
        # driver from the same list; this is the value we expect it to pick, kept
        # on the Result for logging/inspection. nil when the station offered none.
        def negotiated_subprotocol
          offered = (@env["HTTP_SEC_WEBSOCKET_PROTOCOL"] || "").split(/ *, */)
          (@subprotocols & offered).first
        end

        def reject(identifier, failure)
          Result.new(identifier: identifier, failure: failure)
        end
      end
    end
  end
end
