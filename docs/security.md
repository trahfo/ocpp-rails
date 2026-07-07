# Security

OCPP Rails authenticates charge points with **OCPP-J Security Profile 1**
(HTTP Basic Authentication on the WebSocket upgrade) and is secure by
default: connections without a valid per-station credential are rejected
before the channel subscription is confirmed.

## Per-Station Credentials

Each charge point holds its own credential, stored as a SHA-256 digest —
never in plaintext. OCPP-J passwords are high-entropy machine credentials
(the specification mandates 16–40 random bytes), which is why a fast hash
is appropriate here, exactly as for API tokens.

```ruby
# Provision a credential (e.g. in a console or an admin flow)
password = SecureRandom.base58(32)
charge_point.update!(auth_password: password)
# Configure the same identity/password pair on the station.
```

The station must send the credential as HTTP Basic Auth during the
WebSocket handshake, with the **username equal to its charge point
identifier**:

```
Authorization: Basic base64("<identifier>:<password>")
```

A station presenting valid credentials for identifier X can never
subscribe as identifier Y, stations without a configured credential are
rejected, and every failed attempt is logged as a `[OCPP][security]`
warning with the failure reason (never the credential).

## Configuration

```ruby
Ocpp::Rails.setup do |config|
  # :basic (default) — OCPP-J Security Profile 1, HTTP Basic Auth
  # :none            — accept any client that knows a station identifier
  config.authentication_mode = :basic
end
```

`:none` restores the pre-authentication behaviour. Use it only on closed
networks or temporarily while rolling credentials out to a fleet.

## Transport Security (Security Profile 2)

Profile 1 sends the Basic Auth credential in cleartext on the wire, so it
is only acceptable inside trusted networks. For anything reaching the
public internet, run **Security Profile 2**: TLS (`wss://`) terminated in
front of the Rails app (nginx, HAProxy, a cloud load balancer, …) plus the
Basic Auth described above. Client-certificate authentication (Profile 3)
is not implemented; terminate and verify client certificates at the TLS
proxy if you need it today.

## Upgrading

`authentication_mode` defaults to `:basic`, which is a breaking change for
existing installs: stations that connected anonymously will be rejected
until they present credentials.

1. Run the migrations (adds `auth_password_digest` to `ocpp_charge_points`).
2. Provision a credential per station and configure it on the device.
3. Until the fleet is migrated, you can set `config.authentication_mode = :none`
   explicitly — and consciously.
