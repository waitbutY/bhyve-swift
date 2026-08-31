# Changelog

## 0.1.2 — 2026-08-30

Adds public memberwise initializers to `Battery`, `Zone`, `Device`,
`DeviceStatus`, `Program`, `RunTime`, `WateringEvent`, and `Irrigation`.
Previously these `Codable` structs only exposed the synthesized
`Decodable.init(from:)`, so a consumer outside this package (e.g. test
fixtures or UI code building a modified `Program` to send back via
`updateProgram`) couldn't construct one directly. Purely additive, no
behavior change.

## 0.1.1 — 2026-08-30

Fixes the WebSocket handshake against the live Orbit B-hyve server. Two
root causes, both discovered by comparing against the pybhyve reference
client:

- Login was returning `orbit_session_token`, which the WebSocket does
  not accept. Adding `orbit-app-id: Bhyve Dashboard`, `Origin`, and a
  browser-shaped `User-Agent` to REST requests causes the server to
  return `orbit_api_key` (a token with the app-id embedded), which the
  WebSocket does accept. All authenticated REST calls now include these
  headers as well.
- The WebSocket hello was being sent as a binary frame. It must be a
  text frame. The 20 s keepalive is now a text-frame `{"event":"ping"}`
  instead of the WebSocket-protocol PING opcode, which the server
  ignores — it closes idle connections at ~30 s otherwise.

Closes #1. `client.events()`, `startZones`, and `stopWatering` now work.

## 0.1.0 — 2026-08-30

Initial release. REST client (devices, programs, watering events, rain
delay, program update) and WebSocket event stream scaffolding.
