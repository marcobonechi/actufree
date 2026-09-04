"""Generates the Actufree app icon sets.

The mark is an A and an F sharing strokes: the A's right diagonal doubles as
the F's stem, and one horizontal bar serves as both the A's crossbar and the
F's lower arm. Four strokes in total, which is what keeps it legible at 48px.

Shapes are drawn as signed distance fields — one sample per pixel with
analytic anti-aliasing — so no image library is needed and every size is
rendered at its native resolution rather than downscaled.
"""

import math
import os
import struct
import zlib

# Purple ground, light green-blue mark.
BG_TOP = (0x7C, 0x3A, 0xED)
BG_BOTTOM = (0x4C, 0x1D, 0x95)
MARK_TOP = (0xA7, 0xF3, 0xD0)
MARK_BOTTOM = (0x67, 0xE8, 0xF9)

HALF_WIDTH = 0.046

# (ax, ay, bx, by) in a 0..1 square, y down.
STROKES = (
    (0.140, 0.830, 0.380, 0.170),   # A, left diagonal
    (0.380, 0.170, 0.620, 0.830),   # A, right diagonal — also the F's stem
    (0.4345, 0.320, 0.880, 0.320),  # F, upper arm
    (0.2309, 0.580, 0.800, 0.580),  # A crossbar and F lower arm, one stroke
)


def _lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def _distance_to_mark(px, py, strokes):
    best = 9.0
    for ax, ay, bx, by in strokes:
        vx, vy = bx - ax, by - ay
        wx, wy = px - ax, py - ay
        t = (wx * vx + wy * vy) / (vx * vx + vy * vy)
        if t < 0.0:
            t = 0.0
        elif t > 1.0:
            t = 1.0
        dx, dy = wx - t * vx, wy - t * vy
        d = math.sqrt(dx * dx + dy * dy)
        if d < best:
            best = d
    return best


def render(size, mode, corner=0.0, scale=1.0):
    """Renders one icon. Modes: full, background, foreground."""
    aa = 1.2 / size
    half = HALF_WIDTH * scale
    offset = (1.0 - scale) / 2.0
    strokes = tuple(
        (ax * scale + offset, ay * scale + offset,
         bx * scale + offset, by * scale + offset)
        for ax, ay, bx, by in STROKES
    )
    rows = []
    for py in range(size):
        y = (py + 0.5) / size
        row = bytearray()
        for px in range(size):
            x = (px + 0.5) / size
            shade = (x + y) * 0.5

            if mode == 'foreground':
                r, g, b, a = 0, 0, 0, 0
            else:
                r, g, b = _lerp(BG_TOP, BG_BOTTOM, shade)
                a = 255
                if corner > 0.0:
                    # Rounded square, for launchers that do not mask.
                    cx = min(x, 1.0 - x)
                    cy = min(y, 1.0 - y)
                    if cx < corner and cy < corner:
                        dx, dy = corner - cx, corner - cy
                        d = math.sqrt(dx * dx + dy * dy)
                        cover = (corner + aa * 0.5 - d) / aa
                        if cover <= 0.0:
                            a = 0
                        elif cover < 1.0:
                            a = int(255 * cover)

            if mode != 'background':
                d = _distance_to_mark(x, y, strokes)
                cover = (half + aa * 0.5 - d) / aa
                if cover > 0.0:
                    if cover > 1.0:
                        cover = 1.0
                    mr, mg, mb = _lerp(MARK_TOP, MARK_BOTTOM, shade)
                    if mode == 'foreground':
                        r, g, b = mr, mg, mb
                        a = int(255 * cover)
                    else:
                        r = int(r + (mr - r) * cover)
                        g = int(g + (mg - g) * cover)
                        b = int(b + (mb - b) * cover)
            row += bytes((r, g, b, a))
        rows.append(row)
    return rows


def render_banner(width, height):
    """The Play feature graphic: the mark on the left, wordmark space right."""
    aa = 1.2 / height
    rows = []
    for py in range(height):
        y = (py + 0.5) / height
        row = bytearray()
        for px in range(width):
            xf = (px + 0.5) / width
            shade = (xf + y) * 0.5
            r, g, b = _lerp(BG_TOP, BG_BOTTOM, shade)
            # Map the mark into a square block on the left third.
            mx = ((px + 0.5) - height * 0.16) / (height * 0.68)
            my = ((py + 0.5) - height * 0.16) / (height * 0.68)
            if 0.0 <= mx <= 1.0 and 0.0 <= my <= 1.0:
                d = _distance_to_mark(mx, my, STROKES) * 0.68
                cover = (HALF_WIDTH * 0.68 + aa * 0.5 - d) / aa
                if cover > 0.0:
                    if cover > 1.0:
                        cover = 1.0
                    mr, mg, mb = _lerp(MARK_TOP, MARK_BOTTOM, shade)
                    r = int(r + (mr - r) * cover)
                    g = int(g + (mg - g) * cover)
                    b = int(b + (mb - b) * cover)
            row += bytes((r, g, b, 255))
        rows.append(row)
    return rows


def write_png(path, rows, width, keep_alpha=True):
    colour_type = 6 if keep_alpha else 2
    raw = bytearray()
    for row in rows:
        raw.append(0)
        if keep_alpha:
            raw += row
        else:
            for i in range(0, len(row), 4):
                raw += row[i:i + 3]
    height = len(rows)

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))

    header = struct.pack('>IIBBBBB', width, height, 8, colour_type, 0, 0, 0)
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
           + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as handle:
        handle.write(png)


def main():
    app = os.path.join(os.path.dirname(__file__), '..', 'app')
    ios = os.path.join(app, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
    res = os.path.join(app, 'android/app/src/main/res')
    store = os.path.join(os.path.dirname(__file__), '..', '..', 'store')

    # iOS wants opaque squares; the system applies its own mask.
    ios_sizes = {
        'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60, 'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120, 'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180, 'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152, 'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
    }
    cache = {}
    for name, size in sorted(ios_sizes.items(), key=lambda kv: kv[1]):
        if size not in cache:
            cache[size] = render(size, 'full')
        write_png(os.path.join(ios, name), cache[size], size, keep_alpha=False)
        print('ios', name, size)

    # Android: legacy square icons plus an adaptive foreground/background pair.
    legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144,
              'xxxhdpi': 192}
    adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324,
                'xxxhdpi': 432}
    for density, size in legacy.items():
        rows = render(size, 'full', corner=0.22)
        write_png(os.path.join(res, 'mipmap-%s/ic_launcher.png' % density),
                  rows, size)
        print('android legacy', density, size)
    for density, size in adaptive.items():
        # The outer third of an adaptive icon can be cropped, so the mark is
        # scaled into the safe zone rather than filling the canvas.
        write_png(os.path.join(res, 'mipmap-%s/ic_launcher_foreground.png'
                               % density),
                  render(size, 'foreground', scale=0.62), size)
        write_png(os.path.join(res, 'mipmap-%s/ic_launcher_background.png'
                               % density),
                  render(size, 'background'), size)
        print('android adaptive', density, size)

    # Web: the favicon plus the two sizes a browser installs from. A maskable
    # icon may be cropped to a circle, so the mark is scaled into the safe zone
    # while the ground still fills the canvas.
    web = os.path.join(app, 'web')
    write_png(os.path.join(web, 'favicon.png'), render(32, 'full'), 32)
    print('web favicon 32')
    for size in (192, 512):
        write_png(os.path.join(web, 'icons/Icon-%d.png' % size),
                  render(size, 'full'), size)
        write_png(os.path.join(web, 'icons/Icon-maskable-%d.png' % size),
                  render(size, 'full', scale=0.62), size)
        print('web icon', size)

    # The two static pages share the mark, so a tab shows the same thing
    # whether it is the site or the app.
    docs = os.path.join(os.path.dirname(__file__), '..', '..', 'docs')
    write_png(os.path.join(docs, 'favicon.png'), render(32, 'full'), 32)
    print('site favicon 32')

    write_png(os.path.join(store, 'play-icon-512.png'),
              render(512, 'full'), 512, keep_alpha=True)
    print('store icon 512')
    write_png(os.path.join(store, 'play-feature-graphic-1024x500.png'),
              render_banner(1024, 500), 1024, keep_alpha=False)
    print('store feature graphic 1024x500')


if __name__ == '__main__':
    main()
