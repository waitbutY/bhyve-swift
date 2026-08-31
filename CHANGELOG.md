# Changelog

## 0.1.0 — 2026-08-30

Initial release. REST client (devices, programs, watering events, rain delay,
program update) and WebSocket event stream scaffolding. Fixtures captured
against the real API.

Known issue: the live WebSocket handshake is currently dropped by the server;
`client.events()` reconnect-loops without emitting frames. See issue #1. REST
is fully functional.
