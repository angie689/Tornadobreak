# Tornadobreak

A small native iPhone tornado game inspired by Hurricane Outbreak. SwiftUI menus,
SpriteKit gameplay, and Apple MapKit street-map snapshots. iOS 16+, landscape-only,
designed around the iPhone 11 Pro Max in either landscape orientation.

## Play

Drag the thumbstick to steer. Warm, moist **green** bubbles build energy; cool, dry
**blue** bubbles drain it. Moore has stable beginner weather; in every city after it
the bubbles drift, faster and wider as the cities get harder. Camping in one place
becomes much less effective there, and the minimap shows the moving bubbles. From
Wichita onward, even mixed air drains energy, warm bubbles shrink, cool bubbles grow,
and buildings are sturdier, so you must keep chasing the green.

**Overlapping bubbles change the air** (orange, deep-blue and yellow patches on the
map and minimap):

| Overlap | Air | Effect |
|---------|-----|--------|
| warm + warm | Super hot & moist | Energy grows 1.5× as fast |
| cold + cold | Super cold & dry | Energy drains 1.6× as fast (Stability still helps) |
| warm + cold | Mixed air | Slow growth in the easier cities; drains in the hardest |

Because a cold bubble can drift over the middle of a warm one, the best air is not
always at a bubble's centre. Look for clean green, or for two green bubbles overlapping.

Grow from EF0 to EF5: the funnel widens, wind increases, and more objects become
liftable. Pass close to trees, cars, homes, and larger buildings to break them
apart. Trees and cars rise and pull toward the funnel before breaking; heavier
buildings shake as they take damage. Heavier objects take more strength and time,
and large debris slightly drains tornado energy (especially in Chicago).

Finish all three objectives in one run to complete a level. Eight cities, easiest to hardest:

| Location            | Difficulty | Strength | Destruction | Survival | First / replay TC |
|---------------------|------------|----------|-------------|----------|-------------------|
| Moore, Oklahoma     | Easy       | EF2      | 18          | 60 s     | 200 / 50          |
| Dallas, Texas       | Medium     | EF3      | 28          | 85 s     | 320 / 80          |
| Chicago, Illinois   | Hard       | EF5      | 38          | 100 s    | 440 / 110         |
| Wichita, Kansas     | Expert     | EF5      | 46          | 110 s    | 580 / 145         |
| Joplin, Missouri    | Brutal     | EF5      | 54          | 120 s    | 740 / 185         |
| Nashville, Tennessee| Extreme    | EF5      | 60          | 130 s    | 920 / 230         |
| Atlanta, Georgia    | Nightmare  | EF5      | 66          | 140 s    | 1120 / 280        |
| New York, New York  | Legendary  | EF5      | 72          | 150 s    | 1360 / 340        |

Destruction pays 1/3/7/12 TC for trees/cars/houses/buildings. Each objective gives
20 TC **once per level**. First completion pays 100%; all subsequent completions
pay 25%. Coins, quest claims, completed levels, and upgrades save automatically
in device-local storage when earned. Leaving a run resets its objectives, not
its earned coins. At zero energy, reaching better air within 8 seconds can save
you; the low-energy banner counts down those last seconds. Backgrounding pauses
automatically; resume explicitly when you return.

Three permanent upgrade tracks: Suction (+10% lift/rank), Stability (14% less dry-air
loss/rank), and Speed (+12% movement/rank). Each now has **five** ranks, costing
60, 130, 200, 450, and 900 TC; previous three-rank saves remain valid.
Even destroying every object in Moore and Dallas cannot buy every rank.
All locations are available immediately. Upgrades help but are not mandatory.

### Geography and weather

MapKit loads real street maps for fixed city regions without an API key or location
permission. Destructible clusters use latitude/longitude reference points inside each
region (Moore, Dallas and Chicago use hand-placed points; the five newer cities lay
eight clusters around the city centre); individual offsets and building/tree/car types are **game
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
  simulator matching Xcode's iOS SDK. Boot happens after test compilation. Individual
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
Apple's SDKs. Difficulty levers live in each level's `Tuning` (weather drift, camping delay, mixed-air drain, debris cost, object sturdiness, zone sizes). Tests cover growth, weather loss, dissipation, controls/bounds,
upgrades, completion of all eight levels, the difficulty ladder, no-camping wins, one-time rewards, replay payout,
serialization, local save/reload, scene construction, visible lifting, EF/wind
consistency, and menu/pause navigation.

## Small by design

No accounts, ads, shops, multiplayer, analytics, paid maps, or additional currencies.
Cars and trees use custom, transparent player-designed sprite art. Houses and the tornado
keep their original visuals. The tornado uses an eight-frame transparent animated vortex atlas, retaining
natural EF0–EF5 growth and a small capped debris burst. No fluid simulation or fragment physics. There are 120 destructibles
per level and the HUD refreshes at 10 Hz. Sound, haptics, and run resumption after
termination are outside this version.

