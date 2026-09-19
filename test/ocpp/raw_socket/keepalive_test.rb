# frozen_string_literal: true

require "test_helper"
require "socket"

module Ocpp
  module Rails
    module RawSocket
      # Driven against a real loopback socket, and read back with getsockopt:
      # the whole point of these options is what the kernel ends up holding,
      # which a double cannot tell us.
      class KeepaliveTest < ActiveSupport::TestCase
        setup do
          @server = TCPServer.new("127.0.0.1", 0)
          @client = TCPSocket.new("127.0.0.1", @server.addr[1])
          @accepted = @server.accept
          @endpoint = Endpoint.new
        end

        teardown do
          [ @accepted, @client, @server ].each { |io| io.close unless io.nil? || io.closed? }
        end

        test "a station socket is kept alive on the operating system's own timers" do
          @endpoint.send(:enable_tcp_keepalive, @accepted)

          assert @accepted.getsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE).bool
        end

        test "the idle, interval and probe timers are the configured ones" do
          @endpoint.send(:enable_tcp_keepalive, @accepted)

          configuration = Ocpp::Rails.configuration
          idle_option = @endpoint.send(:keepalive_idle_option)

          assert_equal configuration.raw_socket_keepalive_idle,
            @accepted.getsockopt(Socket::IPPROTO_TCP, Socket.const_get(idle_option)).int
          assert_equal configuration.raw_socket_keepalive_interval,
            @accepted.getsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPINTVL).int
          assert_equal configuration.raw_socket_keepalive_probes,
            @accepted.getsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPCNT).int
        end

        test "a timer configured as nil is left to the operating system" do
          before = @accepted.getsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPCNT).int

          with_config(:raw_socket_keepalive_probes, nil) do
            @endpoint.send(:enable_tcp_keepalive, @accepted)
          end

          assert_equal before, @accepted.getsockopt(Socket::IPPROTO_TCP, Socket::TCP_KEEPCNT).int
        end

        # The reader thread hands whatever the hijack produced; a test harness
        # (or a Windows box missing an option) must not take a station down.
        test "an IO that is not a socket is left alone without raising" do
          assert_nothing_raised { @endpoint.send(:enable_tcp_keepalive, StringIO.new) }
        end

        private

        def with_config(key, value)
          original = Ocpp::Rails.configuration.public_send(key)
          Ocpp::Rails.configuration.public_send("#{key}=", value)
          yield
        ensure
          Ocpp::Rails.configuration.public_send("#{key}=", original)
        end
      end
    end
  end
end
