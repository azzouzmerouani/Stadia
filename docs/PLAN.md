# Stadia – build plan

Short plan written before milestone 1; each milestone ends with
`flutter analyze`, `flutter test` and a commit.

| # | Milestone | Outcome |
|---|-----------|---------|
| 1 | Skeleton + glass UI kit + map | go_router + Riverpod app shell, design tokens, glass surface, spring-press buttons, hand-drawn glyphs, splash, OSM map (navy-tinted tiles, attribution) with the swipeable "Upcoming matches" glass card. Mock data layer behind `StadiumRepository`. |
| 2 | Booking state machine | Pure `BookingMachine` (Stand → Block → Seat → Buy) with guards (sold-out blocks, sold seats, wrong stand), Riverpod controller, progress bar + floating info card, unit + widget tests. |
| 3 | Blender stadium | `tools/blender/build_stadium.py` builds the whole bowl from `assets/data/stadium.json` (pitch + markings, track, 4 two-tier stands, 56 blocks, merged seat rows, roof ring, floodlights, concourse), bakes lighting into vertex colours, exports a Draco GLB. |
| 4 | Three.js viewer + bridge | Offline bundle in `assets/web/` served from a loopback HTTP server inside the app, loaded in `webview_flutter`. Raycast picking by mesh name, orbit limits, camera fly-to per step, hover/selected highlight, availability colouring, per-seat instanced mesh, "view from seat" render. JS ⇄ Flutter JSON bridge. 3D intro with Skip. |
| 5 | Seat sheet, checkout, ticket | Seat detail sheet (view from seat, block/row/seat/gate/price, VIP, Another seat / Buy), mock checkout behind `PaymentService` (Chargily slot), "You're in" ticket with notched shape and QR. |
| 6 | Devices + docs | Runs on iOS simulator and Android emulator, README (setup, regenerate model, architecture, mocked vs production). |

Key decisions

- **One source of truth for the seating layout**: `assets/data/stadium.json`
  feeds both the Blender generator and the app's repository, so mesh names
  (`Block_N_101`) always match domain ids (`N_101`).
- **Unlit, baked look**: lighting is baked into per-face vertex colours in
  Blender; the viewer uses `MeshBasicMaterial` (no lights, no shadows, no
  post-processing, pixel ratio ≤ 2) to hold 60 fps on mid-range Android.
- **Per-seat geometry only where needed**: the GLB has merged seat rows per
  block; the viewer instantiates individual seats (one `InstancedMesh`) only
  for the block being picked.
- **Offline web assets**: a tiny `dart:io` server on 127.0.0.1 serves
  `assets/web` + the GLB, avoiding `file://` CORS/WASM limits in WebViews.
