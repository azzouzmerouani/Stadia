"""Procedural low-poly stadium for Stadia.

Run headless (from the repo root):

    blender -b --factory-startup -P tools/blender/build_stadium.py -- \
        --config assets/data/stadium.json --out assets/3d/stadium.glb

Options after `--`:
    --config PATH   stadium layout (stands, blocks, tiers, rows, seats)
    --out PATH      output .glb (Draco compressed unless --no-draco)
    --no-draco      skip Draco compression (bigger, easier to debug)
    --blend PATH    also save the generated .blend for inspection

Axes (Blender, Z-up, metres): +Y = north, +X = east. The glTF exporter
converts to Y-up: (x, y, z) -> (x, z, -y).

Selectable meshes and their names (also stored as glTF node extras):
    Stand_<S>            stand structure        S in N, E, S, W
    Block_<S>_<nnn>      stepped terrace         nnn = tier*100 + index (101, 102, 201...)
    Seats_<S>_<nnn>      merged seat rows of that block. Object origin is the
                         front-left corner of row 1; local +X runs along the
                         row (seat 1 -> seat N), local +Y runs back (row 1 ->
                         row N), local +Z is up. Extras: rows, seats,
                         seat_width, row_depth, row_rise.

Lighting is baked into per-face vertex colours (sun + sky + height AO), so
the viewer renders with unlit materials: no lights, no shadows.
"""

import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

# --------------------------------------------------------------------------
# Arguments
# --------------------------------------------------------------------------


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", ".."))
    p = argparse.ArgumentParser(description="Build the Stadia stadium GLB")
    p.add_argument("--config", default=os.path.join(root, "assets/data/stadium.json"))
    p.add_argument("--out", default=os.path.join(root, "assets/3d/stadium.glb"))
    p.add_argument("--no-draco", action="store_true")
    p.add_argument("--blend", default=None)
    return p.parse_args(argv)


# --------------------------------------------------------------------------
# Fixed geometry (metres). Seating layout comes from the JSON config.
# --------------------------------------------------------------------------

PITCH_LENGTH = 105.0
PITCH_WIDTH = 68.0
TRACK_HALF_STRAIGHT = 42.195  # 84.39 m straights
TRACK_R_IN = 36.5
TRACK_LANES = 8
TRACK_LANE_W = 1.22
TRACK_R_OUT = TRACK_R_IN + TRACK_LANES * TRACK_LANE_W
STAND_GAP = 3.5  # outer track edge -> pitch wall
LINE_W = 0.24  # stylised: thicker than the real 12 cm so it reads on phones
PITCH_WALL = 1.2  # height of the wall in front of row 1
MID_CONCOURSE = 2.6  # depth of the walkway between tiers
FASCIA = 2.6  # height of the upper-tier front wall

STAND_FRONT_EW = TRACK_R_OUT + STAND_GAP
STAND_FRONT_NS = TRACK_HALF_STRAIGHT + TRACK_R_OUT + STAND_GAP

STAND_DIRS = {
    "N": ((0.0, STAND_FRONT_NS), (0.0, 1.0)),
    "E": ((STAND_FRONT_EW, 0.0), (1.0, 0.0)),
    "S": ((0.0, -STAND_FRONT_NS), (0.0, -1.0)),
    "W": ((-STAND_FRONT_EW, 0.0), (-1.0, 0.0)),
}

# sRGB hex; converted to linear for Blender/glTF.
PALETTE = {
    "Ground": "#0A1830",
    "Plaza": "#14264A",
    "Apron": "#1E3258",
    "GrassInfield": "#246B3C",
    "GrassA": "#2F8B4D",
    "GrassB": "#287C44",
    "Lines": "#F4F7FB",
    "Goal": "#FFFFFF",
    "Track": "#A9503B",
    "TrackLines": "#E7D6CF",
    "Boards": "#24396A",
    "Concrete": "#3A4F76",
    "Steps": "#2E4268",
    "Facade": "#1D3056",
    "Doorway": "#0B1426",
    "SeatLower": "#1B7A4A",  # Algerian green
    "SeatUpper": "#E4EAF2",  # white
    "SeatVip": "#C8283C",  # red
    "Roof": "#EEF2F8",
    "RoofUnder": "#AEBBD0",
    "Steel": "#93A3BD",
    "Lamp": "#FFF3C8",
    "FlagGreen": "#1B7A4A",
}

SUN = Vector((0.35, -0.55, 0.76)).normalized()


def to_linear(hex_colour):
    h = hex_colour.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

_materials = {}


def material(key):
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new("M_" + key)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    colour = to_linear(PALETTE[key])
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if key == "Lamp":
        bsdf.inputs["Emission Color"].default_value = colour
        bsdf.inputs["Emission Strength"].default_value = 1.0
    m.diffuse_color = colour
    _materials[key] = m
    return m


# --------------------------------------------------------------------------
# Mesh builder: every face owns its vertices (flat shading, per-face colour)
# --------------------------------------------------------------------------


def newell_normal(pts):
    n = Vector((0.0, 0.0, 0.0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n.normalized() if n.length > 1e-9 else Vector((0.0, 0.0, 1.0))


def signed_area(poly):
    return 0.5 * sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(poly, poly[1:] + poly[:1]))


class MeshBuilder:
    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.face_mat = []
        self.mats = []

    # -- primitives ---------------------------------------------------------

    def face(self, pts, mat, hint=None):
        """Add a polygon; `hint` is the desired normal direction and fixes
        the winding so single-sided rendering works."""
        pts = [Vector(p) for p in pts]
        if hint is not None and newell_normal(pts).dot(Vector(hint)) < 0:
            pts.reverse()
        start = len(self.verts)
        self.verts.extend(pts)
        self.faces.append(tuple(range(start, start + len(pts))))
        if mat not in self.mats:
            self.mats.append(mat)
        self.face_mat.append(self.mats.index(mat))

    def box(self, x0, y0, z0, x1, y1, z1, mat, bottom=False):
        self.face([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], mat, (0, 0, 1))
        if bottom:
            self.face([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], mat, (0, 0, -1))
        self.face([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], mat, (0, -1, 0))
        self.face([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], mat, (0, 1, 0))
        self.face([(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], mat, (-1, 0, 0))
        self.face([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], mat, (1, 0, 0))

    def oriented_box(self, matrix, hx, hy, hz, mat, front_mat=None):
        """Box of half-extents (hx, hy, hz) placed by `matrix`; the local -Y
        face gets `front_mat` (used for floodlight lamps)."""
        rot = matrix.to_3x3()
        faces = [
            ((-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz), (0, 0, 1), mat),
            ((-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz), (0, 0, -1), mat),
            ((-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (0, -1, 0), front_mat or mat),
            ((-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz), (0, 1, 0), mat),
            ((-hx, -hy, -hz), (-hx, hy, -hz), (-hx, hy, hz), (-hx, -hy, hz), (-1, 0, 0), mat),
            ((hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz), (1, 0, 0), mat),
        ]
        for a, b, c, d, hint, m in faces:
            self.face([matrix @ Vector(p) for p in (a, b, c, d)], m, rot @ Vector(hint))

    def prism_x(self, profile, x0, x1, mat, skip_edges=()):
        """Extrude a closed (y, z) profile along X from x0 to x1."""
        sign = 1.0 if signed_area(profile) > 0 else -1.0
        count = len(profile)
        for i in range(count):
            if i in skip_edges:
                continue
            (ya, za), (yb, zb) = profile[i], profile[(i + 1) % count]
            hint = (0.0, sign * (zb - za), -sign * (yb - ya))
            self.face([(x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb)], mat, hint)
        self.face([(x0, y, z) for y, z in profile], mat, (-1, 0, 0))
        self.face([(x1, y, z) for y, z in profile], mat, (1, 0, 0))

    def ribbon(self, pts, width, z, mat, closed=False):
        """Flat strip of `width` centred on a 2D polyline at height z."""
        half = width / 2.0
        count = len(pts)
        pv = [Vector((x, y)) for x, y in pts]
        sides = []
        for i in range(count):
            if closed or 0 < i < count - 1:
                d1 = (pv[i] - pv[(i - 1) % count]).normalized()
                d2 = (pv[(i + 1) % count] - pv[i]).normalized()
                tangent = d1 + d2
                tangent = tangent.normalized() if tangent.length > 1e-9 else d1
                normal = Vector((-tangent.y, tangent.x))
                miter = half / max(0.35, normal.dot(Vector((-d1.y, d1.x))))
            else:
                d = (pv[1] - pv[0]) if i == 0 else (pv[-1] - pv[-2])
                d = d.normalized()
                normal = Vector((-d.y, d.x))
                miter = half
            sides.append((pv[i] + normal * miter, pv[i] - normal * miter))
        segments = count if closed else count - 1
        for i in range(segments):
            a, b = sides[i], sides[(i + 1) % count]
            self.face(
                [(a[0].x, a[0].y, z), (b[0].x, b[0].y, z), (b[1].x, b[1].y, z), (a[1].x, a[1].y, z)],
                mat,
                (0, 0, 1),
            )

    def bridge(self, outer, inner, z_outer, z_inner, mat, hint):
        """Quads between two closed 2D loops with matching vertex counts."""
        count = len(outer)
        for i in range(count):
            j = (i + 1) % count
            self.face(
                [(outer[i][0], outer[i][1], z_outer), (outer[j][0], outer[j][1], z_outer),
                 (inner[j][0], inner[j][1], z_inner), (inner[i][0], inner[i][1], z_inner)],
                mat,
                hint,
            )

    def wall_loop(self, loop, z0, z1, mat):
        """Vertical outward-facing walls around a closed 2D polygon."""
        sign = 1.0 if signed_area(loop) > 0 else -1.0
        count = len(loop)
        for i in range(count):
            (xa, ya), (xb, yb) = loop[i], loop[(i + 1) % count]
            hint = (sign * (yb - ya), -sign * (xb - xa), 0.0)
            self.face([(xa, ya, z0), (xb, yb, z0), (xb, yb, z1), (xa, ya, z1)], mat, hint)

    def disc(self, cx, cy, r, z, mat, segments=20):
        pts = [(cx + r * math.cos(2 * math.pi * i / segments),
                cy + r * math.sin(2 * math.pi * i / segments), z) for i in range(segments)]
        self.face(pts, mat, (0, 0, 1))

    # -- output -----------------------------------------------------------

    def build(self, matrix=None, extras=None, ao=True):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        for key in self.mats:
            me.materials.append(material(key))
        for poly, slot in zip(me.polygons, self.face_mat):
            poly.material_index = slot
        me.update()

        world = matrix if matrix is not None else Matrix.Identity(4)
        rot = world.to_3x3()
        colours = me.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
        for poly in me.polygons:
            normal = (rot @ poly.normal).normalized()
            centre = world @ poly.center
            value = bake_light(normal, centre.z, ao)
            for li in poly.loop_indices:
                colours.data[li].color = (value, value, value, 1.0)
        me.color_attributes.active_color = colours

        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        if matrix is not None:
            ob.matrix_world = matrix
        for key, value in (extras or {}).items():
            ob[key] = value
        return ob


def bake_light(normal, height, ao):
    """Fake 'baked' lighting: sun + sky + darker low down (stands)."""
    direct = max(0.0, normal.dot(SUN))
    sky = 0.5 + 0.5 * normal.z
    value = 0.42 + 0.40 * direct + 0.18 * sky
    if ao:
        value *= 0.78 + 0.22 * min(1.0, max(0.0, height / 26.0))
    return min(1.0, value) ** 1.35


# --------------------------------------------------------------------------
# Shapes
# --------------------------------------------------------------------------


def track_loop(radius, segments=32):
    """Athletics-track oval (two semicircles + straights), counter-clockwise."""
    pts = []
    for i in range(segments + 1):
        t = math.pi * i / segments
        pts.append((radius * math.cos(t), TRACK_HALF_STRAIGHT + radius * math.sin(t)))
    for i in range(segments + 1):
        t = math.pi + math.pi * i / segments
        pts.append((radius * math.cos(t), -TRACK_HALF_STRAIGHT + radius * math.sin(t)))
    return pts


def rounded_rect(hx, hy, r, arc=8, edge=4):
    """Counter-clockwise rounded rectangle with a fixed sample count, so two
    of them can be bridged quad by quad."""
    corners = [(hx - r, hy - r, 0.0), (-hx + r, hy - r, 0.5), (-hx + r, -hy + r, 1.0), (hx - r, -hy + r, 1.5)]
    pts = []
    for idx, (cx, cy, start) in enumerate(corners):
        for i in range(arc + 1):
            t = math.pi * (start + 0.5 * i / arc)
            pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
        end_t = math.pi * (start + 0.5)
        ax, ay = cx + r * math.cos(end_t), cy + r * math.sin(end_t)
        nx, ny, nstart = corners[(idx + 1) % 4]
        bt = math.pi * nstart
        bx, by = nx + r * math.cos(bt), ny + r * math.sin(bt)
        for i in range(1, edge):
            f = i / edge
            pts.append((ax + (bx - ax) * f, ay + (by - ay) * f))
    return pts


def circle_pts(cx, cy, r, a0, a1, segments):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / segments),
             cy + r * math.sin(a0 + (a1 - a0) * i / segments)) for i in range(segments + 1)]


# --------------------------------------------------------------------------
# Scene parts
# --------------------------------------------------------------------------


def build_ground():
    g = MeshBuilder("Ground")
    g.face([(-420, -420, -0.4), (420, -420, -0.4), (420, 420, -0.4), (-420, 420, -0.4)], "Ground", (0, 0, 1))
    g.face([(x, y, -0.2) for x, y in rounded_rect(122, 168, 46)], "Plaza", (0, 0, 1))
    hx, hy = STAND_FRONT_EW + 0.5, STAND_FRONT_NS + 0.5
    g.face([(-hx, -hy, 0.0), (hx, -hy, 0.0), (hx, hy, 0.0), (-hx, hy, 0.0)], "Apron", (0, 0, 1))
    g.build(ao=False)


def build_pitch():
    p = MeshBuilder("Pitch")
    p.face([(x, y, 0.03) for x, y in track_loop(TRACK_R_IN)], "GrassInfield", (0, 0, 1))
    hx, hy, stripes = 34.4, 53.0, 18  # mowing stripes across the pitch
    for i in range(stripes):
        y0 = -hy + 2 * hy * i / stripes
        y1 = -hy + 2 * hy * (i + 1) / stripes
        p.face([(-hx, y0, 0.05), (hx, y0, 0.05), (hx, y1, 0.05), (-hx, y1, 0.05)],
               "GrassA" if i % 2 == 0 else "GrassB", (0, 0, 1))
    p.build(ao=False)

    lines = MeshBuilder("Pitch_Lines")
    z = 0.08
    w2, l2 = PITCH_WIDTH / 2, PITCH_LENGTH / 2
    lines.ribbon([(-w2, -l2), (w2, -l2), (w2, l2), (-w2, l2)], LINE_W, z, "Lines", closed=True)
    lines.ribbon([(-w2, 0), (w2, 0)], LINE_W, z, "Lines")
    lines.ribbon(circle_pts(0, 0, 9.15, 0, 2 * math.pi, 48)[:-1], LINE_W, z, "Lines", closed=True)
    lines.disc(0, 0, 0.3, z, "Lines")
    for s in (1, -1):
        goal_y = s * l2
        for half_w, depth in ((20.16, 16.5), (9.16, 5.5)):  # penalty + goal area
            lines.ribbon([(-half_w, goal_y), (-half_w, goal_y - s * depth),
                          (half_w, goal_y - s * depth), (half_w, goal_y)], LINE_W, z, "Lines")
        spot = goal_y - s * 11.0
        lines.disc(0, spot, 0.25, z, "Lines")
        alpha = math.acos(5.5 / 9.15)  # the part of the arc outside the box
        towards_centre = -math.pi / 2 if s > 0 else math.pi / 2
        lines.ribbon(circle_pts(0, spot, 9.15, towards_centre - alpha, towards_centre + alpha, 16),
                     LINE_W, z, "Lines")
        for cx in (-w2, w2):  # corner arcs (r = 1 m) curving into the pitch
            ax = 0.0 if cx < 0 else math.pi
            ay = math.pi / 2 if goal_y < 0 else -math.pi / 2
            if ay - ax > math.pi:
                ay -= 2 * math.pi
            elif ay - ax < -math.pi:
                ay += 2 * math.pi
            lines.ribbon(circle_pts(cx, goal_y, 1.0, ax, ay, 6), LINE_W, z, "Lines")
    lines.build(ao=False)

    goals = MeshBuilder("Goals")
    post = 0.07
    for s in (1, -1):
        gy = s * l2
        back = gy + s * 2.0
        for gx in (-3.66, 3.66):
            goals.box(gx - post, gy - post, 0, gx + post, gy + post, 2.44, "Goal")
            goals.box(gx - 0.04, back - 0.04, 0, gx + 0.04, back + 0.04, 1.6, "Goal")
        goals.box(-3.66 - post, gy - post, 2.44 - 2 * post, 3.66 + post, gy + post, 2.44, "Goal")
        y0, y1 = sorted((gy, back))
        goals.box(-3.66, y0, 2.36, -3.6, y1, 2.44, "Goal")
        goals.box(3.6, y0, 2.36, 3.66, y1, 2.44, "Goal")
    for cx in (-w2, w2):  # corner flags
        for cy in (-l2, l2):
            goals.box(cx - 0.04, cy - 0.04, 0, cx + 0.04, cy + 0.04, 1.6, "Goal")
            goals.face([(cx, cy, 1.6), (cx, cy, 1.15), (cx + (0.55 if cx > 0 else -0.55), cy, 1.38)],
                       "FlagGreen", (0, -1 if cy > 0 else 1, 0))
    goals.build(ao=False)

    boards = MeshBuilder("Boards")  # perimeter advertising boards
    for sx in (-1, 1):
        x = sx * 35.6
        boards.box(min(x, x + sx * 0.12), -40, 0, max(x, x + sx * 0.12), 40, 0.9, "Boards")
    for sy in (-1, 1):
        y = sy * 56.0
        boards.box(-14, min(y, y + sy * 0.12), 0, 14, max(y, y + sy * 0.12), 0.9, "Boards")
    boards.build(ao=False)


def build_track():
    t = MeshBuilder("Track")
    t.bridge(track_loop(TRACK_R_OUT), track_loop(TRACK_R_IN), 0.02, 0.02, "Track", (0, 0, 1))
    t.build(ao=False)

    lines = MeshBuilder("Track_Lines")
    for lane in range(TRACK_LANES + 1):
        lines.ribbon(track_loop(TRACK_R_IN + lane * TRACK_LANE_W), 0.09, 0.045, "TrackLines", closed=True)
    lines.face([(-TRACK_R_OUT, -0.1, 0.05), (-TRACK_R_IN, -0.1, 0.05),
                (-TRACK_R_IN, 0.3, 0.05), (-TRACK_R_OUT, 0.3, 0.05)], "TrackLines", (0, 0, 1))
    lines.build(ao=False)


def stand_profile(cfg):
    """Tier placement in a stand's local frame (y = distance from the pitch
    wall, z = height)."""
    layout = cfg["layout"]
    depth = layout["rowDepth"]
    tiers = []
    offset, base = 0.0, PITCH_WALL
    for i, t in enumerate(layout["tiers"]):
        rows, rise = t["rows"], t["rise"]
        tier = dict(tier=t["tier"], off=offset, base=base, rows=rows, rise=rise,
                    depth=rows * depth, top=base + rows * rise)
        tiers.append(tier)
        offset += rows * depth
        if i < len(layout["tiers"]) - 1:
            offset += MID_CONCOURSE
            base = tier["top"] + FASCIA
    return tiers, offset


def stand_matrix(front, out):
    """Local frame of a stand: +X along the stand (clockwise around the bowl
    seen from above), +Y away from the pitch, +Z up. Right-handed, so face
    windings survive the transform."""
    ux, uy = out
    vx, vy = uy, -ux
    return Matrix((
        (vx, ux, 0.0, front[0]),
        (vy, uy, 0.0, front[1]),
        (0.0, 0.0, 1.0, 0.0),
        (0.0, 0.0, 0.0, 1.0),
    ))


def seat_colour(stand_id, tier, index, count):
    if tier > 1:
        return "SeatUpper"
    if stand_id == "W" and abs(index - (count - 1) / 2) < 1.1:
        return "SeatVip"
    return "SeatLower"


def build_stands(cfg):
    layout = cfg["layout"]
    block_w = layout["blockWidth"]
    seat_w = layout["seatWidth"]
    row_d = layout["rowDepth"]
    seats_per_row = layout["seatsPerRow"]
    seat_run = seats_per_row * seat_w
    aisle = (block_w - seat_run) / 2.0
    tiers, back = stand_profile(cfg)
    back_top = tiers[-1]["top"] + 1.6
    block_ids = []

    for stand in cfg["stands"]:
        sid = stand["id"]
        front, out = STAND_DIRS[sid]
        per_tier = stand["blocksPerTier"]
        length = per_tier * block_w
        half = length / 2.0
        frame = stand_matrix(front, out)

        # ---- structure ---------------------------------------------------
        s = MeshBuilder("Stand_" + sid)
        s.face([(-half, 0, 0), (half, 0, 0), (half, 0, PITCH_WALL), (-half, 0, PITCH_WALL)], "Concrete", (0, -1, 0))
        for i, t in enumerate(tiers[:-1]):
            nxt = tiers[i + 1]
            y0, y1 = t["off"] + t["depth"], nxt["off"]
            s.face([(-half, y0, t["top"]), (half, y0, t["top"]), (half, y1, t["top"]), (-half, y1, t["top"])],
                   "Concrete", (0, 0, 1))
            s.face([(-half, y1, t["top"]), (half, y1, t["top"]), (half, y1, nxt["base"]), (-half, y1, nxt["base"])],
                   "Facade", (0, -1, 0))
            for b in range(per_tier):  # vomitory doorways, one per block
                cx = -half + (b + 0.5) * block_w
                s.face([(cx - 1.6, y1 - 0.03, t["top"]), (cx + 1.6, y1 - 0.03, t["top"]),
                        (cx + 1.6, y1 - 0.03, t["top"] + 2.1), (cx - 1.6, y1 - 0.03, t["top"] + 2.1)],
                       "Doorway", (0, -1, 0))
        last = tiers[-1]
        s.box(-half - 0.6, back, 0, half + 0.6, back + 0.6, back_top, "Facade")
        s.face([(-half, back - 0.001, last["top"]), (half, back - 0.001, last["top"]),
                (half, back - 0.001, back_top), (-half, back - 0.001, back_top)], "Concrete", (0, -1, 0))
        profile = [(0.0, 0.0), (0.0, PITCH_WALL + 0.9)]  # side walls hug the nosings + parapet
        for i, t in enumerate(tiers):
            profile.append((t["off"] + t["depth"], t["top"] + 0.9))
            if i < len(tiers) - 1:
                nxt = tiers[i + 1]
                profile.append((nxt["off"], t["top"] + 0.9))
                profile.append((nxt["off"], nxt["base"] + 0.9))
        profile.append((back + 0.6, back_top))
        profile.append((back + 0.6, 0.0))
        bottom_edge = (len(profile) - 1,)
        s.prism_x(profile, -half - 0.6, -half, "Concrete", skip_edges=bottom_edge)
        s.prism_x(profile, half, half + 0.6, "Concrete", skip_edges=bottom_edge)
        s.build(frame, extras={
            "stadia_kind": "stand",
            "stadia_stand": sid,
            "stadia_out": [out[0], out[1], 0.0],
            "stadia_length": length,
            "stadia_depth": back,
            "stadia_height": back_top,
        })

        # ---- blocks + seats ---------------------------------------------
        for t in tiers:
            for b in range(per_tier):
                number = t["tier"] * 100 + b + 1
                block_id = f"{sid}_{number}"
                origin = frame @ Matrix.Translation((-half + b * block_w, t["off"], t["base"]))

                steps = MeshBuilder("Block_" + block_id)
                for r in range(t["rows"]):
                    y0, y1 = r * row_d, (r + 1) * row_d
                    z0, z1 = r * t["rise"], (r + 1) * t["rise"]
                    steps.face([(0, y0, z0), (block_w, y0, z0), (block_w, y1, z0), (0, y1, z0)], "Steps", (0, 0, 1))
                    steps.face([(0, y1, z0), (block_w, y1, z0), (block_w, y1, z1), (0, y1, z1)], "Steps", (0, -1, 0))
                steps.build(origin, extras={
                    "stadia_kind": "block",
                    "stadia_stand": sid,
                    "stadia_block": block_id,
                    "stadia_tier": t["tier"],
                })

                seats = MeshBuilder("Seats_" + block_id)
                colour = seat_colour(sid, t["tier"], b, per_tier)
                for r in range(t["rows"]):
                    y0, z0 = r * row_d, r * t["rise"]
                    profile = [
                        (y0 + 0.14, z0), (y0 + 0.14, z0 + 0.40), (y0 + 0.50, z0 + 0.44),
                        (y0 + 0.58, z0 + 0.86), (y0 + 0.68, z0 + 0.86), (y0 + 0.68, z0),
                    ]
                    seats.prism_x(profile, 0.0, seat_run, colour, skip_edges=(5,))
                seats.build(origin @ Matrix.Translation((aisle, 0.0, 0.0)), extras={
                    "stadia_kind": "seats",
                    "stadia_stand": sid,
                    "stadia_block": block_id,
                    "stadia_tier": t["tier"],
                    "stadia_rows": t["rows"],
                    "stadia_seats": seats_per_row,
                    "stadia_seat_width": seat_w,
                    "stadia_row_depth": row_d,
                    "stadia_row_rise": t["rise"],
                    "stadia_colour": colour,
                })
                block_ids.append(block_id)
    return back, back_top, block_ids


def build_corners(cfg, back):
    """Low concourse buildings closing the four open corners."""
    block_w = cfg["layout"]["blockWidth"]
    ew_end = max(s["blocksPerTier"] for s in cfg["stands"] if s["id"] in ("E", "W")) * block_w / 2
    ns_end = max(s["blocksPerTier"] for s in cfg["stands"] if s["id"] in ("N", "S")) * block_w / 2
    x_front, y_front = STAND_FRONT_EW + 1.2, STAND_FRONT_NS + 1.2
    x_back, y_back = STAND_FRONT_EW + back, STAND_FRONT_NS + back
    c = MeshBuilder("Concourse")
    for sx in (1, -1):
        for sy in (1, -1):
            loop = [
                (x_front, ew_end + 0.8), (x_back, ew_end + 0.8), (x_back, y_front + 6),
                (ns_end + 22, y_back), (ns_end + 0.8, y_back), (ns_end + 0.8, y_front),
                (x_front, y_front - 8),
            ]
            loop = [(sx * x, sy * y) for x, y in loop]
            c.face([(x, y, 9.0) for x, y in loop], "Concrete", (0, 0, 1))
            c.wall_loop(loop, 0.0, 9.0, "Facade")
    c.build()


def build_roof(back, back_top):
    inner = rounded_rect(STAND_FRONT_EW + 19, STAND_FRONT_NS + 19, 26)
    outer = rounded_rect(STAND_FRONT_EW + back + 3, STAND_FRONT_NS + back + 3, 52)
    z_in, z_out, thick = back_top + 7.5, back_top + 4.5, 0.8
    r = MeshBuilder("Roof")
    r.bridge(outer, inner, z_out, z_in, "Roof", (0, 0, 1))
    r.bridge(outer, inner, z_out - thick, z_in - thick, "RoofUnder", (0, 0, -1))
    count = len(inner)
    for i in range(count):
        j = (i + 1) % count
        r.face([(inner[i][0], inner[i][1], z_in - thick), (inner[j][0], inner[j][1], z_in - thick),
                (inner[j][0], inner[j][1], z_in), (inner[i][0], inner[i][1], z_in)],
               "Roof", (-inner[i][0], -inner[i][1], 0))
        r.face([(outer[i][0], outer[i][1], z_out - thick), (outer[j][0], outer[j][1], z_out - thick),
                (outer[j][0], outer[j][1], z_out), (outer[i][0], outer[i][1], z_out)],
               "Roof", (outer[i][0], outer[i][1], 0))
    r.build(ao=False)

    cols = MeshBuilder("Roof_Supports")
    for i in range(0, len(outer), 2):
        x, y = outer[i][0] * 0.97, outer[i][1] * 0.97
        cols.box(x - 0.5, y - 0.5, 0, x + 0.5, y + 0.5, z_out - thick, "Steel")
    cols.build()


def build_floodlights(back):
    f = MeshBuilder("Floodlights")
    x0, y0 = STAND_FRONT_EW + back + 14, STAND_FRONT_NS + back + 10
    height = 58.0
    for sx in (1, -1):
        for sy in (1, -1):
            x, y = sx * x0, sy * y0
            f.box(x - 0.8, y - 0.8, 0, x + 0.8, y + 0.8, height, "Steel")
            yaw = math.atan2(-y, -x)  # towards the centre spot
            head = (Matrix.Translation((x, y, height + 3.0))
                    @ Matrix.Rotation(yaw + math.pi / 2, 4, "Z")
                    @ Matrix.Rotation(math.radians(28), 4, "X"))
            f.oriented_box(head, 6.5, 0.5, 3.6, "Steel", front_mat="Lamp")
    f.build(ao=False)


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------


def export(path, draco):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kwargs = dict(
        filepath=path,
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=True,
        export_extras=True,
        export_normals=False,
        export_texcoords=False,
        export_tangents=False,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_skins=False,
        export_morph=False,
    )
    if draco:
        kwargs.update(
            export_draco_mesh_compression_enable=True,
            export_draco_mesh_compression_level=7,
            export_draco_position_quantization=14,
            export_draco_color_quantization=8,
        )
    bpy.ops.export_scene.gltf(**kwargs)


def main():
    args = parse_args()
    with open(args.config, encoding="utf-8") as fh:
        cfg = json.load(fh)

    bpy.ops.wm.read_factory_settings(use_empty=True)

    build_ground()
    build_pitch()
    build_track()
    back, back_top, blocks = build_stands(cfg)
    build_corners(cfg, back)
    build_roof(back, back_top)
    build_floodlights(back)

    tris = sum(len(p.vertices) - 2 for ob in bpy.data.objects for p in ob.data.polygons)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend))
    out = os.path.abspath(args.out)
    export(out, draco=not args.no_draco)
    size = os.path.getsize(out)
    seats = sum(
        cfg["layout"]["seatsPerRow"] * t["rows"] * sum(s["blocksPerTier"] for s in cfg["stands"])
        for t in cfg["layout"]["tiers"]
    )
    print(f"[stadia] objects={len(bpy.data.objects)} blocks={len(blocks)} seats={seats} "
          f"triangles~{tris} size={size / 1024:.0f} KB draco={not args.no_draco} -> {out}")
    if size > 5 * 1024 * 1024:
        print("[stadia] WARNING: GLB is larger than 5 MB")
        sys.exit(2)


if __name__ == "__main__":
    main()
