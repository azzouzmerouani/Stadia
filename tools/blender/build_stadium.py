"""Procedural low-poly stadium for Stadia.

Run headless (from the repo root):

    blender -b --factory-startup -P tools/blender/build_stadium.py -- \
        --config assets/data/stadium.json --out assets/3d/stadium.glb

Options after `--`:
    --config PATH   stadium layout (stands, blocks, tiers, rows, seats)
    --out PATH      output .glb (Draco compressed unless --no-draco)
    --no-draco      skip Draco compression (bigger, easier to debug)
    --blend PATH    also save the generated .blend for inspection
    --no-env        skip the surroundings (just the stadium on a plain ground)

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

Everything else (meshes named Env_*) is the night-time neighbourhood: sea to
the north, hills, roads and street lights, car parks, palms, the aquatic
centre and sports hall, training pitches and a low-rise city with lit
windows. It is baked darker than the floodlit bowl; emissive materials
(windows, lamps) skip the bake. `--no-env` builds the bowl alone.
"""

import argparse
import json
import math
import os
import random
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
    p.add_argument("--no-env", action="store_true")
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

# sRGB hex; converted to linear for Blender/glTF. Night palette, tuned to
# the app's FPL purples.
PALETTE = {
    "Ground": "#140C1F",
    "Plaza": "#2A2140",
    "Apron": "#2F2547",
    "GrassInfield": "#246B3C",
    "GrassA": "#2F8B4D",
    "GrassB": "#287C44",
    "Lines": "#F4F7FB",
    "Goal": "#FFFFFF",
    "Track": "#A9503B",
    "TrackLines": "#E7D6CF",
    "Boards": "#37003C",  # FPL purple advertising boards
    "Concrete": "#463E66",
    "Steps": "#3A3358",
    "Facade": "#2A2247",
    "Doorway": "#0F0A1C",
    "SeatLower": "#1B7A4A",  # Algerian green
    "SeatUpper": "#E4EAF2",  # white
    "SeatVip": "#C8283C",  # red
    "Roof": "#EEF2F8",
    "RoofUnder": "#B4AECB",
    "Steel": "#9A96B3",
    "Lamp": "#FFF3C8",
    "FlagGreen": "#1B7A4A",
    # ---- surroundings
    "Terrain": "#1A1226",
    "Hill": "#2E2140",
    "Sea": "#0E0B2E",
    "Shore": "#3A3560",
    "Park": "#173D2C",
    "TrainingGrass": "#2A7446",
    "Asphalt": "#231A31",
    "RoadMark": "#8E87A6",
    "Kerb": "#3B3150",
    "Parking": "#272037",
    "Bay": "#5E5878",
    "BuildA": "#6E6584",
    "BuildB": "#5C546F",
    "BuildC": "#7D7290",
    "BuildD": "#4E4762",
    "RoofTop": "#3A3349",
    "Glass": "#2D5C8C",
    "HallRoof": "#CDD0DC",
    "PoolRoof": "#E2E6EE",
    "Pole": "#6A6680",
    "Trunk": "#5B4632",
    "Frond": "#2C6B42",
    "CarWhite": "#D9D9E3",
    "CarSilver": "#9C9BAE",
    "CarBlack": "#2A2833",
    "CarRed": "#B02A3E",
    "CarBlue": "#2F4F8F",
    "CarGlass": "#141320",
    # emissive: full colour, no baked shading
    "Window": "#FFD48A",
    "WindowCool": "#CFE6FF",
    "GlassLit": "#7FE7FF",
    "StreetLight": "#FFE3A6",
    "PitchLight": "#F4F8FF",
    "Headlight": "#FFF6D8",
    "Taillight": "#FF2E4D",
    "Beacon": "#FF3355",
}

EMISSIVE = {"Lamp", "Window", "WindowCool", "GlassLit", "StreetLight", "PitchLight",
            "Headlight", "Taillight", "Beacon"}

# The surroundings are dimmer than the floodlit bowl (multiplies the bake).
ENV_DIM = 0.6

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

    def oriented_box(self, matrix, hx, hy, hz, mat, front_mat=None, back_mat=None, bottom=True):
        """Box of half-extents (hx, hy, hz) placed by `matrix`; the local -Y
        face gets `front_mat` (floodlight lamps, headlights), +Y `back_mat`."""
        rot = matrix.to_3x3()
        faces = [
            ((-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz), (0, 0, 1), mat),
            ((-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz), (0, 0, -1), mat),
            ((-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (0, -1, 0), front_mat or mat),
            ((-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz), (0, 1, 0), back_mat or mat),
            ((-hx, -hy, -hz), (-hx, hy, -hz), (-hx, hy, hz), (-hx, -hy, hz), (-1, 0, 0), mat),
            ((hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz), (1, 0, 0), mat),
        ]
        for a, b, c, d, hint, m in faces:
            if not bottom and hint == (0, 0, -1):
                continue
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

    def build(self, matrix=None, extras=None, ao=True, dim=1.0):
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
        for poly, slot in zip(me.polygons, self.face_mat):
            if self.mats[slot] in EMISSIVE:
                value = 1.0
            else:
                normal = (rot @ poly.normal).normalized()
                centre = world @ poly.center
                value = bake_light(normal, centre.z, ao) * dim
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


def build_ground(env):
    g = MeshBuilder("Ground")
    if not env:  # otherwise Env_Terrain is the ground
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
# Surroundings (night): a stylised Bir El Djir, Oran. Sea to the north, a
# Murdjadjo-like ridge to the west, the Mediterranean Games sports park
# around the stadium, the city around that.
# --------------------------------------------------------------------------

EXTENT = 2400.0  # terrain / sea half-size (fog hides the edges)
CITY = 1600.0  # buildings and streets stop here
COAST_Y = 760.0
HIGHWAY_Y = 450.0  # coastal highway, E-W
AVENUE_Y = -360.0  # avenue through the roundabout, E-W
RING = (134.0, 180.0, 52.0)  # ring road centre line: half-x, half-y, corner radius
ROUNDABOUT_R = 24.0

# Layer heights: far ground layers sit apart so they don't z-fight.
Z_SEA, Z_TERRAIN = -2.2, -1.2
Z_ROAD, Z_EW, Z_NS, Z_LOT, Z_WALK = -0.72, -0.69, -0.66, -0.62, -0.5

# Hills: (centre, unit axis, length, width, peak height)
RIDGES = [
    ((-1060.0, -80.0), (0.22, 0.975), 2000.0, 540.0, 260.0),
    ((1250.0, -1300.0), (0.9, 0.44), 1500.0, 460.0, 130.0),
]

STREETS_X = [-1340.0, -1080.0, -820.0, -560.0, -300.0, 300.0, 560.0, 820.0, 1080.0, 1340.0]
STREETS_Y = [-1320.0, -1080.0, -840.0, -600.0]


def coast_y(x):
    return COAST_Y + 48 * math.sin(x / 170.0) + 22 * math.sin(x / 47.0 + 1.3)


def ridge_local(ridge, x, y):
    (cx, cy), (ux, uy), length, width, _ = ridge
    dx, dy = x - cx, y - cy
    return (dx * ux + dy * uy) / length, (-dx * uy + dy * ux) / width


def on_hills(x, y, margin=0.0):
    for r in RIDGES:
        s, t = ridge_local(r, x, y)
        if abs(s) < 0.5 + margin and abs(t) < 0.42 + margin:
            return True
    return False


def off_hills(a, b, step=30.0):
    """Split segment a-b into the pieces that are not on the hills."""
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    n = max(1, int(length / step))
    pts = [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n + 1)]
    pieces, cur = [], []
    for p in pts:
        if on_hills(p[0], p[1], 0.02):
            if len(cur) > 1:
                pieces.append((cur[0], cur[-1]))
            cur = []
        else:
            cur.append(p)
    if len(cur) > 1:
        pieces.append((cur[0], cur[-1]))
    return pieces


def build_terrain():
    t = MeshBuilder("Env_Terrain")
    step = 60.0
    xs = [-EXTENT + i * step for i in range(int(2 * EXTENT / step) + 1)]
    for xa, xb in zip(xs, xs[1:]):
        ya, yb = coast_y(xa), coast_y(xb)
        t.face([(xa, -EXTENT, Z_TERRAIN), (xb, -EXTENT, Z_TERRAIN), (xb, yb, Z_TERRAIN), (xa, ya, Z_TERRAIN)],
               "Terrain", (0, 0, 1))
        t.face([(xa, ya, Z_TERRAIN), (xb, yb, Z_TERRAIN), (xb, yb + 16, Z_SEA), (xa, ya + 16, Z_SEA)],
               "Shore", (0, 0, 1))
        t.face([(xa, ya + 16, Z_SEA), (xb, yb + 16, Z_SEA), (xb, EXTENT * 1.4, Z_SEA), (xa, EXTENT * 1.4, Z_SEA)],
               "Sea", (0, 0, 1))
    t.build(ao=False, dim=ENV_DIM)


def build_hills(rng):
    h = MeshBuilder("Env_Hills")
    for (cx, cy), (ux, uy), length, width, peak in RIDGES:
        nx, ny = 22, 8
        grid = []
        for i in range(nx + 1):
            s = -0.5 + i / nx
            row = []
            for j in range(ny + 1):
                t = -0.5 + j / ny
                env = max(0.0, math.cos(math.pi * s)) * max(0.0, math.cos(math.pi * t))
                bumps = 0.72 + 0.18 * math.sin(i * 1.9 + j * 0.7) + 0.1 * math.sin(i * 0.55 - j * 1.3)
                z = Z_TERRAIN - 0.3 + peak * (env ** 1.25) * bumps
                if 0 < i < nx and 0 < j < ny:
                    z += rng.uniform(-6.0, 6.0) * env
                row.append((cx + ux * s * length - uy * t * width, cy + uy * s * length + ux * t * width, z))
            grid.append(row)
        for i in range(nx):
            for j in range(ny):
                a, b, c, d = grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]
                h.face([a, b, c], "Hill", (0, 0, 1))
                h.face([a, c, d], "Hill", (0, 0, 1))
    h.build(ao=False, dim=ENV_DIM * 1.15)


def dashed(m, a, b, z, dash=5.0, gap=8.0, width=0.22):
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    if length < dash:
        return
    ux, uy = (b[0] - a[0]) / length, (b[1] - a[1]) / length
    d = gap / 2
    while d + dash < length:
        m.ribbon([(a[0] + ux * d, a[1] + uy * d), (a[0] + ux * (d + dash), a[1] + uy * (d + dash))],
                 width, z, "RoadMark")
        d += dash + gap


def lamps_along(a, b, spacing, offset, lamps, both=False):
    """Street lamp positions along a-b, `offset` metres to its left (and
    right when `both`): (x, y, dir_x, dir_y) with dir pointing at the road."""
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    ux, uy = (b[0] - a[0]) / length, (b[1] - a[1]) / length
    nx, ny = -uy, ux
    n = int(length / spacing)
    for i in range(n + 1):
        px, py = a[0] + ux * i * spacing, a[1] + uy * i * spacing
        for side in ((1, -1) if both else (1,)):
            lamps.append((px + nx * offset * side, py + ny * offset * side, -nx * side, -ny * side))


def build_roads(rng):
    r = MeshBuilder("Env_Roads")
    lamps = []
    cars = []  # (x, y, heading) of cars driving with their lights on

    # Ring road round the plaza, its sidewalk and lamps.
    hx, hy, rad = RING
    ring = rounded_rect(hx, hy, rad, arc=10, edge=6)
    r.ribbon(ring, 12.0, Z_ROAD, "Asphalt", closed=True)
    r.ribbon(ring, 0.25, Z_ROAD + 0.03, "RoadMark", closed=True)
    r.ribbon(rounded_rect(hx - 7.5, hy - 7.5, rad - 6, arc=10, edge=6), 5.0, Z_WALK, "Kerb", closed=True)
    outer = rounded_rect(hx + 7.5, hy + 7.5, rad + 7.5, arc=10, edge=6)
    for i in range(0, len(outer), 2):
        x, y = outer[i]
        d = math.hypot(x, y)
        lamps.append((x, y, -x / d, -y / d))

    # North access road to the coastal highway.
    r.ribbon([(0.0, hy + 6.0), (0.0, HIGHWAY_Y - 15.0)], 12.0, Z_NS, "Asphalt")
    dashed(r, (0.0, hy + 6.0), (0.0, HIGHWAY_Y - 15.0), Z_NS + 0.03)
    lamps_along((0.0, hy + 14.0), (0.0, HIGHWAY_Y - 20.0), 34.0, 8.0, lamps, both=True)

    # Boulevard south: two carriageways and a palm median, through a roundabout.
    edge = math.sqrt((ROUNDABOUT_R + 5.5) ** 2 - 7.25 ** 2)
    spans = [(-(hy + 6.0), AVENUE_Y + edge), (AVENUE_Y - edge, -CITY)]
    for y0, y1 in spans:
        for sx in (-1, 1):
            r.ribbon([(sx * 7.25, y0), (sx * 7.25, y1)], 10.5, Z_ROAD, "Asphalt")
            dashed(r, (sx * 7.25, y0), (sx * 7.25, y1), Z_ROAD + 0.03)
            lamps_along((sx * 14.0, y0 - 6.0), (sx * 14.0, y1), 40.0, 0.0, lamps)
            for i in range(int(abs(y1 - y0) / 55.0)):
                cars.append((sx * (7.25 + 2.6 * (1 if rng.random() < 0.5 else -1) * 0.6),
                             y0 + (y1 - y0) * rng.random(), -math.pi / 2 if sx > 0 else math.pi / 2))
        r.ribbon([(0.0, y0), (0.0, y1)], 4.0, Z_WALK, "Park")
    r.ribbon(circle_pts(0.0, AVENUE_Y, ROUNDABOUT_R, 0, 2 * math.pi, 36)[:-1], 11.0, Z_ROAD, "Asphalt", closed=True)
    r.disc(0.0, AVENUE_Y, ROUNDABOUT_R - 5.6, Z_WALK, "Park", segments=28)

    # The avenue through the roundabout.
    for x0, x1 in ((-CITY, -ROUNDABOUT_R - 5.0), (ROUNDABOUT_R + 5.0, CITY)):
        for a, b in off_hills((x0, AVENUE_Y), (x1, AVENUE_Y)):
            r.ribbon([a, b], 16.0, Z_ROAD, "Asphalt")
            dashed(r, a, b, Z_ROAD + 0.03)
            lamps_along(a, b, 48.0, 10.0, lamps, both=True)
            for i in range(int(abs(b[0] - a[0]) / 70.0)):
                east = rng.random() < 0.5
                cars.append((a[0] + (b[0] - a[0]) * rng.random(), AVENUE_Y + (-3.0 if east else 3.0),
                             0.0 if east else math.pi))

    # Coastal highway (goes into the hills: a tunnel).
    for a, b in off_hills((-EXTENT, HIGHWAY_Y), (EXTENT, HIGHWAY_Y)):
        r.ribbon([a, b], 30.0, Z_ROAD, "Asphalt")
        for off in (-10.5, -4.5, 4.5, 10.5):
            dashed(r, (a[0], HIGHWAY_Y + off), (b[0], HIGHWAY_Y + off), Z_ROAD + 0.03, dash=7.0, gap=11.0)
        r.box(a[0], HIGHWAY_Y - 0.4, Z_ROAD, b[0], HIGHWAY_Y + 0.4, Z_ROAD + 0.9, "Kerb")
        lamps_along((a[0], HIGHWAY_Y), (b[0], HIGHWAY_Y), 60.0, 0.0, lamps)
        for i in range(int(abs(b[0] - a[0]) / 22.0)):
            lane = rng.choice((-12.0, -7.5, -3.0, 3.0, 7.5, 12.0))
            cars.append((a[0] + (b[0] - a[0]) * rng.random(), HIGHWAY_Y + lane, 0.0 if lane < 0 else math.pi))

    # City grid.
    for y in STREETS_Y:
        for a, b in off_hills((-CITY, y), (CITY, y)):
            r.ribbon([a, b], 12.0, Z_EW, "Asphalt")
            lamps_along(a, b, 70.0, 7.5, lamps)
    for x in STREETS_X:
        for y0, y1 in ((-CITY, HIGHWAY_Y - 15.0), (HIGHWAY_Y + 15.0, coast_y(x) - 24.0)):
            for a, b in off_hills((x, y0), (x, y1)):
                r.ribbon([a, b], 12.0, Z_NS, "Asphalt")
                lamps_along(a, b, 70.0, 7.5, lamps)

    # Seafront promenade.
    prom = [(x, coast_y(x) - 9.0) for x in range(-1000, 1201, 40) if not on_hills(x, coast_y(x) - 9.0, 0.02)]
    r.ribbon(prom, 7.0, Z_WALK, "Kerb")
    r.build(ao=False, dim=ENV_DIM)
    return lamps, cars, prom


def build_street_lights(lamps):
    """Poles with glowing heads."""
    poles = MeshBuilder("Env_StreetLights")
    for x, y, dx, dy in lamps:
        poles.box(x - 0.16, y - 0.16, Z_TERRAIN, x + 0.16, y + 0.16, 9.5, "Pole")
        hx, hy = x + dx * 1.4, y + dy * 1.4
        poles.box(hx - 0.55, hy - 0.55, 9.2, hx + 0.55, hy + 0.55, 9.6, "StreetLight", bottom=True)
    poles.build(ao=False, dim=ENV_DIM)


def car(m, rng, x, y, heading, z, lights=False):
    colour = rng.choices(("CarWhite", "CarSilver", "CarBlack", "CarRed", "CarBlue"), (5, 4, 3, 1, 1))[0]
    base = (Matrix.Translation((x, y, z + 0.55)) @ Matrix.Rotation(heading + math.pi / 2, 4, "Z"))
    # Local -Y is the front.
    m.oriented_box(base, 0.9, 2.2, 0.38, colour,
                   front_mat="Headlight" if lights else None,
                   back_mat="Taillight" if lights else None, bottom=False)
    cabin = base @ Matrix.Translation((0.0, 0.25, 0.62))
    m.oriented_box(cabin, 0.8, 1.15, 0.26, "CarGlass", bottom=False)


def build_car_parks(rng, road_cars):
    lots = MeshBuilder("Env_CarParks")
    cars = MeshBuilder("Env_Cars")
    hx = RING[0] + 13.0
    for sx in (-1, 1):
        x_in, x_out = hx, hx + 104.0
        x0, x1 = sorted((sx * x_in, sx * x_out))
        y0, y1 = -120.0, 120.0
        lots.face([(x0, y0, Z_LOT), (x1, y0, Z_LOT), (x1, y1, Z_LOT), (x0, y1, Z_LOT)], "Parking", (0, 0, 1))
        for k in range(5):
            aisle = x_in + 2.0 + k * 19.4
            for row in range(2):
                rx0 = aisle + 7.0 + row * 5.2
                rx1 = rx0 + 5.2
                facing = math.pi if row == 0 else 0.0  # nose towards the row's back line
                y = y0 + 1.0
                while y + 2.6 <= y1 - 1.0:
                    a, b = sorted((sx * rx0, sx * rx1))
                    lots.face([(a, y, Z_LOT + 0.04), (b, y, Z_LOT + 0.04), (b, y + 0.15, Z_LOT + 0.04),
                               (a, y + 0.15, Z_LOT + 0.04)], "Bay", (0, 0, 1))
                    if rng.random() < 0.6:  # matchday: busy
                        cx = sx * (rx0 + rx1) / 2
                        car(cars, rng, cx + rng.uniform(-0.15, 0.15), y + 1.3,
                            (facing if sx > 0 else math.pi - facing) + rng.uniform(-0.05, 0.05), Z_LOT)
                    y += 2.6
    for x, y, heading in road_cars:
        car(cars, rng, x, y, heading, Z_ROAD, lights=True)
    lots.build(ao=False, dim=ENV_DIM)
    cars.build(ao=False, dim=ENV_DIM * 1.1)


def palm(m, rng, x, y, z=Z_WALK):
    height = rng.uniform(7.5, 11.0)
    lean_x, lean_y = rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)
    top = (x + lean_x, y + lean_y, z + height)
    r0, r1 = 0.36, 0.22
    for i in range(4):
        a0, a1 = math.pi / 2 * i + 0.4, math.pi / 2 * (i + 1) + 0.4
        m.face([(x + r0 * math.cos(a0), y + r0 * math.sin(a0), z),
                (x + r0 * math.cos(a1), y + r0 * math.sin(a1), z),
                (top[0] + r1 * math.cos(a1), top[1] + r1 * math.sin(a1), top[2]),
                (top[0] + r1 * math.cos(a0), top[1] + r1 * math.sin(a0), top[2])],
               "Trunk", (math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2), 0))
    spin = rng.uniform(0, 2 * math.pi)
    for k in range(7):
        a = spin + 2 * math.pi * k / 7
        dx, dy = math.cos(a), math.sin(a)
        sxv, syv = -dy, dx
        length = rng.uniform(3.6, 4.6)
        mid = (top[0] + dx * length * 0.45, top[1] + dy * length * 0.45, top[2] + 0.5)
        tip = (top[0] + dx * length, top[1] + dy * length, top[2] - 1.6)
        left = (mid[0] + sxv * 0.6, mid[1] + syv * 0.6, mid[2])
        right = (mid[0] - sxv * 0.6, mid[1] - syv * 0.6, mid[2])
        m.face([top, left, tip], "Frond", (0, 0, 1))
        m.face([top, tip, right], "Frond", (0, 0, 1))


def build_palms(rng, promenade):
    m = MeshBuilder("Env_Palms")
    plaza = rounded_rect(RING[0] - 10.0, RING[1] - 10.0, RING[2] - 10.0, arc=10, edge=6)
    for x, y in plaza[::2]:
        palm(m, rng, x, y)
    for y in range(-200, -int(CITY) + 400, -22):
        if abs(y - AVENUE_Y) > ROUNDABOUT_R + 8:
            palm(m, rng, 0.0, float(y))
    for k in range(6):
        a = 2 * math.pi * k / 6
        palm(m, rng, 9.0 * math.cos(a), AVENUE_Y + 9.0 * math.sin(a))
    for x, y in promenade[::1]:
        palm(m, rng, x, y + 4.0)
    m.build(ao=False, dim=ENV_DIM * 1.15)


def lit_band(m, x0, y0, x1, y1, z0, z1, normal, mat):
    """An emissive quad just in front of a wall (x0,y0)-(x1,y1)."""
    ox, oy = normal[0] * 0.08, normal[1] * 0.08
    m.face([(x0 + ox, y0 + oy, z0), (x1 + ox, y1 + oy, z0), (x1 + ox, y1 + oy, z1), (x0 + ox, y0 + oy, z1)],
           mat, (normal[0], normal[1], 0))


def build_sports_park():
    """Aquatic centre, sports hall and lit training pitches round the stadium."""
    m = MeshBuilder("Env_SportsPark")
    z = Z_WALK

    # Aquatic centre (north-west): glass walls under a wave roof.
    cx, cy, hx, hy = -112.0, 312.0, 62.0, 36.0
    profile = [(-hy, z), (hy, z), (hy, 9.0), (28.0, 14.0), (18.0, 18.0), (6.0, 20.5),
               (-6.0, 21.0), (-18.0, 19.5), (-28.0, 15.5), (-hy, 11.0)]
    count = len(profile)
    for i in range(count):
        (ya, za), (yb, zb) = profile[i], profile[(i + 1) % count]
        if i == count - 1 or za <= z + 0.01 and zb <= z + 0.01:
            mat = "Glass"
        else:
            mat = "PoolRoof" if min(za, zb) > 8.5 and not (ya == yb) else "Glass"
        if za <= z + 0.01 and zb <= z + 0.01:
            continue  # floor
        hint = (0.0, (zb - za), -(yb - ya))
        m.face([(cx - hx, cy + ya, za), (cx + hx, cy + ya, za), (cx + hx, cy + yb, zb), (cx - hx, cy + yb, zb)],
               mat, hint)
    m.face([(cx - hx, cy + yy, zz) for yy, zz in profile], "Glass", (-1, 0, 0))
    m.face([(cx + hx, cy + yy, zz) for yy, zz in profile], "Glass", (1, 0, 0))
    for side in (-1, 1):
        y = cy + side * hy
        for k in range(8):
            xa = cx - hx + 3.0 + k * (2 * hx - 6.0) / 8
            xb = xa + (2 * hx - 6.0) / 8 - 1.6
            lit_band(m, xa, y, xb, y, z + 1.5, z + 6.5, (0, side), "GlassLit")

    # Sports hall (north-east).
    cx, cy, hx, hy, h = 116.0, 300.0, 48.0, 34.0, 16.0
    m.face([(cx - hx, cy - hy, h), (cx + hx, cy - hy, h), (cx + hx, cy + hy, h), (cx - hx, cy + hy, h)],
           "HallRoof", (0, 0, 1))
    walls = [((cx - hx, cy - hy), (cx + hx, cy - hy), (0, -1)), ((cx + hx, cy - hy), (cx + hx, cy + hy), (1, 0)),
             ((cx + hx, cy + hy), (cx - hx, cy + hy), (0, 1)), ((cx - hx, cy + hy), (cx - hx, cy - hy), (-1, 0))]
    for (xa, ya), (xb, yb), n in walls:
        m.face([(xa, ya, z), (xb, yb, z), (xb, yb, h), (xa, ya, h)], "BuildD", (n[0], n[1], 0))
        lit_band(m, xa + (xb - xa) * 0.04, ya + (yb - ya) * 0.04, xa + (xb - xa) * 0.96, ya + (yb - ya) * 0.96,
                 z + 1.2, z + 4.6, n, "GlassLit")

    # Two lit training pitches (south), either side of the boulevard.
    for sx in (-1, 1):
        cx, cy, hx, hy = sx * 80.0, -270.0, 45.0, 29.0
        m.face([(cx - hx, cy - hy, z + 0.05), (cx + hx, cy - hy, z + 0.05), (cx + hx, cy + hy, z + 0.05),
                (cx - hx, cy + hy, z + 0.05)], "TrainingGrass", (0, 0, 1))
        lz = z + 0.09
        m.ribbon([(cx - hx + 3, cy - hy + 3), (cx + hx - 3, cy - hy + 3), (cx + hx - 3, cy + hy - 3),
                  (cx - hx + 3, cy + hy - 3)], 0.2, lz, "Lines", closed=True)
        m.ribbon([(cx, cy - hy + 3), (cx, cy + hy - 3)], 0.2, lz, "Lines")
        m.ribbon(circle_pts(cx, cy, 7.0, 0, 2 * math.pi, 24)[:-1], 0.2, lz, "Lines", closed=True)
        for px in (cx - hx - 3, cx + hx + 3):
            for py in (cy - hy - 3, cy + hy + 3):
                m.box(px - 0.25, py - 0.25, z, px + 0.25, py + 0.25, 16.0, "Pole")
                m.box(px - 1.3, py - 1.3, 16.0, px + 1.3, py + 1.3, 16.8, "PitchLight", bottom=True)
    m.build(ao=False, dim=0.85)


def building(m, rng, x0, y0, x1, y1, floors):
    h = Z_WALK + floors * 3.2
    z0 = Z_TERRAIN
    m.face([(x0, y0, h), (x1, y0, h), (x1, y1, h), (x0, y1, h)], "RoofTop", (0, 0, 1))
    mat = rng.choice(("BuildA", "BuildB", "BuildC", "BuildD"))
    walls = [((x0, y0), (x1, y0), (0, -1)), ((x1, y0), (x1, y1), (1, 0)),
             ((x1, y1), (x0, y1), (0, 1)), ((x0, y1), (x0, y0), (-1, 0))]
    for (xa, ya), (xb, yb), n in walls:
        m.face([(xa, ya, z0), (xb, yb, z0), (xb, yb, h), (xa, ya, h)], mat, (n[0], n[1], 0))
        span = math.hypot(xb - xa, yb - ya)
        ux, uy = (xb - xa) / span, (yb - ya) / span
        if rng.random() < 0.3:  # shopfronts
            lit_band(m, xa + ux * 1.5, ya + uy * 1.5, xb - ux * 1.5, yb - uy * 1.5,
                     Z_WALK + 0.4, Z_WALK + 2.6, n, "Window")
        if rng.random() < 0.2:
            continue  # a dark side
        for f in range(1, floors):
            if rng.random() > 0.42:
                continue
            a = rng.uniform(1.0, span * 0.55)
            b = min(span - 1.0, a + rng.uniform(2.0, span * 0.5))
            zf = Z_WALK + f * 3.2 + 1.0
            lit_band(m, xa + ux * a, ya + uy * a, xa + ux * b, ya + uy * b, zf, zf + 1.3, n,
                     "Window" if rng.random() < 0.72 else "WindowCool")
    if floors >= 12:
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        m.box(cx - 0.6, cy - 0.6, h, cx + 0.6, cy + 0.6, h + 1.4, "Beacon")
    elif rng.random() < 0.35:
        cx, cy = x0 + (x1 - x0) * rng.uniform(0.25, 0.75), y0 + (y1 - y0) * rng.uniform(0.25, 0.75)
        m.box(cx - 2.0, cy - 1.5, h, cx + 2.0, cy + 1.5, h + 2.2, "RoofTop")


def build_city(rng):
    m = MeshBuilder("Env_City")
    xs = [-CITY] + STREETS_X[:5] + [0.0] + STREETS_X[5:] + [CITY]
    ys = [-CITY] + STREETS_Y + [AVENUE_Y, HIGHWAY_Y, COAST_Y + 80.0]
    count = 0
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            xa, xb, ya, yb = xs[i], xs[i + 1], ys[j], ys[j + 1]
            if ya >= AVENUE_Y and yb <= HIGHWAY_Y and -300.0 <= xa and xb <= 300.0:
                continue  # the sports park
            inset_x0 = 0.0 if xa == -CITY else (22.0 if xa == 0.0 else 13.0)
            inset_x1 = 0.0 if xb == CITY else (22.0 if xb == 0.0 else 13.0)
            inset_y0 = 0.0 if ya == -CITY else (22.0 if ya == HIGHWAY_Y else 13.0)
            inset_y1 = 24.0 if yb == HIGHWAY_Y else 13.0
            y = ya + inset_y0
            while y < yb - inset_y1:
                depth = rng.uniform(20.0, 38.0)
                x = xa + inset_x0
                while x < xb - inset_x1:
                    width = rng.uniform(22.0, 52.0)
                    x1, y1 = x + width, y + depth
                    cx, cy = x + width / 2, y + depth / 2
                    dist = math.hypot(cx, cy)
                    keep = 0.86 * min(1.0, max(0.3, 1.35 - dist / 1500.0))
                    if (x1 <= xb - inset_x1 and y1 <= yb - inset_y1 and rng.random() < keep
                            and not on_hills(cx, cy, 0.05) and y1 < coast_y(cx) - 28.0
                            and not on_hills(x, y, 0.02) and not on_hills(x1, y1, 0.02)):
                        floors = rng.randint(2, 6)
                        if cy > HIGHWAY_Y:
                            floors += rng.randint(2, 7)  # seafront
                        if cx > 500:
                            floors += 2  # towards central Oran
                        if rng.random() < 0.04:
                            floors = rng.randint(13, 22)
                        building(m, rng, x, y, x1, y1, floors)
                        count += 1
                    x = x1 + rng.uniform(5.0, 12.0)
                y += depth + rng.uniform(7.0, 14.0)
    m.build(ao=True, dim=ENV_DIM)
    return count


def build_ships(rng):
    m = MeshBuilder("Env_Ships")
    for x, length in ((-420.0, 120.0), (380.0, 80.0), (980.0, 150.0)):
        y = coast_y(x) + rng.uniform(260.0, 520.0)
        z = Z_SEA
        m.box(x - length / 2, y - 7, z, x + length / 2, y + 7, z + 6.0, "BuildD")
        m.box(x + length * 0.2, y - 5, z + 6.0, x + length * 0.42, y + 5, z + 15.0, "BuildA")
        for k in range(int(length / 9)):
            xa = x - length / 2 + 4 + k * 9
            lit_band(m, xa, y - 7, xa + 2.5, y - 7, z + 3.2, z + 4.0, (0, -1), "Window")
        m.box(x + length * 0.3 - 0.6, y - 0.6, z + 15.0, x + length * 0.3 + 0.6, y + 0.6, z + 17.0, "Beacon")
    m.build(ao=False, dim=ENV_DIM)


def build_environment():
    rng = random.Random(2026)
    build_terrain()
    build_hills(rng)
    lamps, road_cars, promenade = build_roads(rng)
    build_street_lights(lamps)
    build_car_parks(rng, road_cars)
    build_palms(rng, promenade)
    build_sports_park()
    buildings = build_city(rng)
    build_ships(rng)
    print(f"[stadia] environment: buildings={buildings} lamps={len(lamps)} road_cars={len(road_cars)}")


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

    build_ground(env=not args.no_env)
    build_pitch()
    build_track()
    back, back_top, blocks = build_stands(cfg)
    build_corners(cfg, back)
    build_roof(back, back_top)
    build_floodlights(back)
    if not args.no_env:
        build_environment()

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
