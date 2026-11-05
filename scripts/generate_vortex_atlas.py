#!/usr/bin/env python3
"""Generate the vortex's coherent 24-frame atlas from an analytic cloud field.

Requires numpy and Pillow. Run from any directory. Frames are row-major in a
6x4 grid. Each is 192 px square, with at least 8 transparent border pixels.
Positive phase is counterclockwise in SpriteKit's y-up coordinate system.
No random values or independently drawn frames: every frame samples exactly the
same field at rotated coordinates. This also makes frame 23 -> 0 seamless.
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image

FRAME_SIZE = 192
FRAME_COUNT = 24
COLUMNS = 6
ROWS = 4
SUPERSAMPLE = 2
OUTPUT = Path(__file__).resolve().parents[1] / (
    'Tornadobreak/Assets.xcassets/TornadoVortexAtlas.imageset/TornadoVortexAtlas.png'
)


def smoothstep(low, high, value):
    t = np.clip((value - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


def cloud_field(x, y):
    """A single storm: asymmetric curled cloud bands around a recessed eye."""
    r = np.sqrt(x * x + y * y)
    theta = np.arctan2(y, x)
    # Polar warping curls all texture into the inflowing bands. Integer angular
    # frequencies ensure there is no seam at the atan2 branch cut.
    spiral = theta + 4.7 * r + 0.18 * np.sin(8 * r)
    u, v = r * np.cos(spiral), r * np.sin(spiral)
    noise = np.zeros_like(r)
    for frequency, amplitude, offset in [(18, .32, .4), (37, .18, 1.9), (74, .09, 3.1), (143, .045, .7)]:
        noise += amplitude * np.sin(u * frequency + offset) * np.cos(v * frequency * .91 - offset)
    bands = (.5 + .5 * np.cos(3 * spiral + .35 * np.sin(theta))) ** 2.5
    filaments = (.5 + .5 * np.cos(11 * spiral + 30 * r + noise * 3)) ** 6
    # Let the spiral bands taper into separate wisps instead of a hard disc.
    outer = 1 - smoothstep(.56 + .12 * bands, .73 + .16 * bands, r)
    envelope = outer * smoothstep(.085, .20, r)
    opacity = np.clip((.46 + .48 * bands + .28 * noise + .10 * filaments) * envelope, 0, .96)
    # A muted, translucent eye provides depth without an opaque circular badge.
    eye = .35 * (1 - smoothstep(.065, .16, r))
    alpha = opacity + eye * (1 - opacity)
    light = np.clip(.42 + .34 * bands + .25 * noise + .12 * filaments, 0, 1)
    light *= .65 + .35 * smoothstep(.13, .30, r)
    dark = np.array([51., 64., 73.])
    bright = np.array([215., 230., 229.])
    rgb = dark + light[..., None] * (bright - dark)
    rgb = np.where((opacity > .001)[..., None], rgb, dark)
    return np.dstack((rgb, alpha * 255)).clip(0, 255).astype(np.uint8)


def render_frame(index):
    size = FRAME_SIZE * SUPERSAMPLE
    axis = (np.arange(size) + .5) * (2 / size) - 1
    x, y_down = np.meshgrid(axis, axis)
    y = -y_down
    phase = index * math.tau / FRAME_COUNT
    c, s = math.cos(phase), math.sin(phase)
    # Inverse rotation maps output coordinates into the immutable source field.
    pixels = cloud_field(c * x + s * y, -s * x + c * y)
    return Image.fromarray(pixels).resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)


def generate():
    atlas = Image.new('RGBA', (COLUMNS * FRAME_SIZE, ROWS * FRAME_SIZE))
    for index in range(FRAME_COUNT):
        atlas.paste(render_frame(index), ((index % COLUMNS) * FRAME_SIZE, (index // COLUMNS) * FRAME_SIZE))
    atlas.save(OUTPUT, optimize=True)
    print(f'{OUTPUT}: {atlas.width}x{atlas.height}; {FRAME_COUNT} frames; {OUTPUT.stat().st_size:,} bytes')


if __name__ == '__main__':
    generate()
