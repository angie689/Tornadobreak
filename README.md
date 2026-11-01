# Tornadobreak

A small native iPhone tornado game inspired by Hurricane Outbreak. SwiftUI menus,
SpriteKit gameplay, and Apple MapKit street-map snapshots. iOS 16+, portrait,
designed around the 414 × 896 point iPhone 11 Pro Max screen.

## Play

Drag the thumbstick to steer. Warm, moist **green** zones build energy; cool, dry
**blue** zones drain it. The overview map shows your position and weather zones.
Grow from EF0 to EF5: the funnel widens, wind increases, and more objects become
liftable. Pass close to trees, cars, homes, and larger buildings to break them
apart. Trees and cars rise and pull toward the funnel before breaking; heavier
buildings shake as they take damage. Heavier objects take more strength and time.

Finish all three objectives in one run to complete a level:

| Location | Difficulty | Strength | Destruction | Survival | First / replay TC |
|---|---|---|---|---|---|
| Moore, Oklahoma | Easy | EF2 | 18 | 60 s | 200 / 50 |
| Dallas, Texas | Medium | EF3 | 28 | 85 s | 320 / 80 |
| Chicago, Illinois | Hard | EF4 | 38 | 100 s | 440 / 110 |

Destruction pays 1/3/7/12 TC for trees/cars/houses/buildings. Each objective gives
20 TC **once per level**. First completion pays 100%; all subsequent completions
pay 25%. Coins, quest claims, completed levels, and upgrades save automatically
in device-local storage when earned. Leaving a run resets its objectives, not
its earned coins. At zero energy, reaching better air within 8 seconds can save
you; the low-energy banner counts down those last seconds. Backgrounding pauses
automatically; resume explicitly when you return.

Only three upgrades: Suction (+10% lift/rank), Stability (14% less loss/rank),
Speed (+12% movement/rank). Each has three ranks costing 60, 130, and 200 TC.
All locations are available immediately. Upgrades help but are not mandatory.

### Geography and weather

MapKit loads real street maps for fixed city regions without an API key or location
permission. Destructible clusters use explicit latitude/longitude reference points
inside each region; individual offsets and building/tree/car types are **game
placements**, not actual parcel inventories. Weather is fictional gameplay data,
not live weather. EF and wind are simplified game estimates, not safety guidance.
The wind display stays within the corresponding [NWS EF wind band](https://www.weather.gov/grb/efscale)
(EF5 is capped at 220 mph for gameplay). Apple attribution remains visible.
When a snapshot cannot load, the app clearly
labels its reference grid; it never substitutes a fictional street map. Maps
require connectivity; the rest of gameplay and saving work offline.

## Download an iPhone build (no Mac required)

1. Open [Actions → Build iPhone game](https://github.com/angie689/Tornadobreak/actions/workflows/ios.yml).
2. Choose a successful run on `main`. Download **Tornadobreak-iPhone** under Artifacts
   (GitHub sign-in may be required). The workflow also runs automatically on pushes.
3. Unzip the artifact, then unzip `Tornadobreak-iPhone.zip` to get `Tornadobreak.ipa`.
4. Import the IPA in an **already configured SideStore**. It re-signs with your Apple ID.

The app is unsigned and cannot install directly from Files. No paid Apple Developer
membership is needed for the build or personal-account signing where SideStore
supports it. SideStore's setup/pairing requirements, app limits, compatibility,
and signing refresh rules still apply; initial setup may require a computer.
Actual installation must be checked on a physical iPhone. Uninstalling may erase saves.

The workflow runs two jobs in parallel on macOS 15 Intel with Xcode 16.4:

- **Core tests and iPhone ZIP** runs the complete core gameplay/economy suite,
  builds the unsigned arm64 Release app, and packages and verifies both archives.
  Compiled core tests are cached by compiler, architecture, and source content;
  the tests still execute on every build.
- **Native app and UI checks** runs app integration and UI tests on an installed
  simulator matching Xcode's iOS SDK. Boot overlaps test compilation. Individual
  tests and simulator steps have time limits so a stalled simulator fails promptly.
  Core tests are not compiled and run a second time inside the simulator app.

The **Tornadobreak-iPhone** ZIP becomes downloadable when its own job passes;
there is no wait for simulator UI automation. This artifact has passed core tests,
device compilation, and archive checks, but **both jobs must be green to call the
whole build verified**. A simulator failure remains visible and fails the workflow.
Both archives undergo CRC checks; the validator checks the nested IPA, bundle
metadata, and native Mach-O executable before upload. Gameplay, Release compiler
settings, signing, and archive validation are unchanged. Documentation-only pushes
skip automatic builds; manual builds remain available.

## Build and test locally

On a Mac with Xcode 16+ and its iOS simulator:

```sh
brew install xcodegen
xcodegen generate
open Tornadobreak.xcodeproj
```

`project.yml` is the source of truth for the project. No team or signing identity
is configured. Use a simulator, or let SideStore sign the generated IPA. A normal
Xcode device install requires your own signing setup.

```sh
swift test
xcodebuild test -project Tornadobreak.xcodeproj -scheme Tornadobreak \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Tornadobreak.xcodeproj -scheme Tornadobreak \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO
scripts/package_ipa.sh
```

Use an installed simulator name. CI chooses an installed iPhone on the active SDK's
runtime; it does not choose a newer, unrelated runtime or download another one.
Core tests run with Swift 5.9+ on Linux or macOS. The app and UI tests require
Apple's SDKs. Tests cover growth, weather loss, dissipation, controls/bounds,
upgrades, completion of all three levels, one-time rewards, replay payout,
serialization, local save/reload, scene construction, visible lifting, EF/wind
consistency, and menu/pause navigation.

## Small by design

No accounts, ads, shops, multiplayer, analytics, paid maps, or additional currencies.
There is no real-time fluid simulation: the tornado uses six animated arcs and a
small capped debris burst, with no fragment physics. There are 120 destructibles
per level and the HUD refreshes at 10 Hz. Sound, haptics, run resumption after
termination, and additional maps are outside version 1.0.

