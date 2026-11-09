"""Draws the app icon (1024x1024 PNG) with the Python standard library only.

A soft champagne four-pointed star – the same shape as the app's buttons (OrganicStar.swift) –
on a warm night background with a gentle glow and two tiny stars.

Usage: py -3 Tools/make_app_icon.py App/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""
import math
import struct
import sys
import zlib

SIZE = 1024
SUBROWS = 4  # vertical supersampling; horizontal coverage is computed exactly


def star_outline(cx, cy, scale):
    """The 24x24 OrganicStar path as a polygon, centred at (cx, cy)."""
    def p(x, y):
        return (cx + (x - 12) * scale, cy + (y - 12) * scale)

    segments = [
        ((12, 2), (12.9, 7.2), (13.4, 8.6), (15.4, 10.1)),
        ((15.4, 10.1), (17.1, 11.4), (19, 11.6), (22, 12)),
        ((22, 12), (19, 12.4), (17.1, 12.6), (15.4, 13.9)),
        ((15.4, 13.9), (13.4, 15.4), (12.9, 16.8), (12, 22)),
        ((12, 22), (11.1, 16.8), (10.6, 15.4), (8.6, 13.9)),
        ((8.6, 13.9), (6.9, 12.6), (5, 12.4), (2, 12)),
        ((2, 12), (5, 11.6), (6.9, 11.4), (8.6, 10.1)),
        ((8.6, 10.1), (10.6, 8.6), (11.1, 7.2), (12, 2)),
    ]
    points = []
    for p0, p1, p2, p3 in segments:
        a, b, c, d = p(*p0), p(*p1), p(*p2), p(*p3)
        for i in range(32):
            t = i / 32
            u = 1 - t
            x = u ** 3 * a[0] + 3 * u * u * t * b[0] + 3 * u * t * t * c[0] + t ** 3 * d[0]
            y = u ** 3 * a[1] + 3 * u * u * t * b[1] + 3 * u * t * t * c[1] + t ** 3 * d[1]
            points.append((x, y))
    return points


def coverage(polygon):
    """Anti-aliased coverage (0..1) of a polygon on the SIZE x SIZE grid, as a dict row -> list."""
    edges = []
    n = len(polygon)
    for i in range(n):
        (x0, y0), (x1, y1) = polygon[i], polygon[(i + 1) % n]
        if y0 != y1:
            edges.append((x0, y0, x1, y1))
    ys = [p[1] for p in polygon]
    top, bottom = max(0, int(min(ys))), min(SIZE - 1, int(max(ys)) + 1)
    rows = {}
    for row in range(top, bottom + 1):
        acc = [0.0] * SIZE
        touched = False
        for s in range(SUBROWS):
            y = row + (s + 0.5) / SUBROWS
            xs = []
            for x0, y0, x1, y1 in edges:
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for left, right in zip(xs[0::2], xs[1::2]):
                left, right = max(0.0, left), min(float(SIZE), right)
                if right <= left:
                    continue
                touched = True
                first, last = int(left), int(math.ceil(right)) - 1
                for px in range(first, last + 1):
                    covered = min(right, px + 1) - max(left, px)
                    if covered > 0:
                        acc[px] += covered / SUBROWS
        if touched:
            rows[row] = acc
    return rows


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def hex_rgb(value):
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)


def write_png(path, pixels):
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        raw.extend(row)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main(path):
    core = hex_rgb(0x3A3128)      # warm centre of the web version's night background
    edge = hex_rgb(0x0B0A09)      # Palette.background
    glow = hex_rgb(0xD6CDB4)      # Palette.accent (champagne)
    star_top = hex_rgb(0xF3ECD8)
    star_bottom = hex_rgb(0xC8B996)

    cx, cy = SIZE / 2, SIZE * 0.5
    main_star = coverage(star_outline(cx, cy, SIZE * 0.0285))
    tiny_stars = [
        (coverage(star_outline(SIZE * 0.235, SIZE * 0.245, SIZE * 0.0042)), 0.75),
        (coverage(star_outline(SIZE * 0.775, SIZE * 0.745, SIZE * 0.0032)), 0.55),
    ]

    pixels = []
    for y in range(SIZE):
        row = bytearray()
        star_row = main_star.get(y)
        for x in range(SIZE):
            nx, ny = (x + 0.5) / SIZE - 0.5, (y + 0.5) / SIZE - 0.46
            d = math.sqrt(nx * nx + ny * ny)
            color = mix(core, edge, min(1.0, (d / 0.72) ** 1.35))
            # Soft champagne halo behind the star.
            halo = 0.22 * math.exp(-(d / 0.24) ** 2)
            color = mix(color, glow, halo)
            for tiny, strength in tiny_stars:
                tiny_row = tiny.get(y)
                if tiny_row and tiny_row[x] > 0:
                    color = mix(color, star_top, tiny_row[x] * strength)
            if star_row and star_row[x] > 0:
                fill = mix(star_top, star_bottom, min(1.0, max(0.0, (y - SIZE * 0.2) / (SIZE * 0.6))))
                color = mix(color, fill, star_row[x])
            row.extend(int(round(min(255, max(0, c)))) for c in color)
        pixels.append(row)
    write_png(path, pixels)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png")
