# Fixtures

Real API responses captured against a live B-hyve account on 2026-08-30,
with PII scrubbed (see scrub.py in the design notes).

## Contents

- `session.json` — response of `POST /v1/session`
- `user.json` — response of `GET /v1/users/{user_id}`
- `devices.json` — response of `GET /v1/devices?user_id=…`
  - Contains two device types: `bridge` (Wi-Fi Hub) and `sprinkler_timer`.
  - Only `sprinkler_timer` carries `battery` and `zones`.
- `watering_events__*.json` — response of `GET /v1/watering_events/{device_id}` (per device)
- `programs__*.json` — response of `GET /v1/sprinkler_timer_programs?device_id=…` (per device)
- `ws_frames.json` — captured WebSocket frames (may be empty on some captures; see WS README)

Field-name discovery notes:
- Session token key is `orbit_session_token`, not `orbit_api_key`.
- The `type` discriminator for devices is `"bridge"` or `"sprinkler_timer"`.
