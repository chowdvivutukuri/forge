"""Exercise form animations: single source of truth.

Each movement is authored as two key poses (A and B) of a simple figure, mostly in
the side (sagittal) plane. Joints are solved with forward kinematics (angles) or
two-bone IK (targets) so limbs keep their length and hands/feet stay planted.
The solved figure is lifted to 3D (shoulder and hip width, arms that move out to
the side, legs that spread), then sampled into frames. The apps only interpolate
frames and project them for any viewing angle (side, front, back, or rotating).

Run `python3 tools/forms/forms.py` to regenerate:
  - Shared/forms.json        (bundled in the iPhone and Watch apps)
  - tools/forms/sheet*.png   (with --sheet: side and front views of every pattern)

World units: roughly a 100 x 100 box, y up, ground at y=4.
Side-authored poses: x = forward (figure faces +x). lat = sideways (negative = near side).
"""
import json, math, os, sys

GROUND = 4.0
L = dict(shin=19.0, thigh=19.0, torso=25.0, upper=14.0, fore=13.0, neck=2.5, head=5.0,
         foot=5.5, ffoot=3.0, sh_off=7.5, hip_off=4.0)
NFRAMES = 13

# ---------- limb specs ----------
# pl: plane for arms in side-authored patterns: "s" side (default), "f" frontal (x = outward, y = up),
#     "h" horizontal at shoulder height (x = outward, y = forward).

def ang(u, f, fa=None, pl="s"):
    return dict(m="ang", a=u, b=f, rel="w", bend=1, fa=fa, pl=pl)

def ik(x, y, bend, rel="w", fa=None, pl="s"):
    return dict(m="ik", a=x, b=y, rel=rel, bend=bend, fa=fa, pl=pl)

def st(x, y, rel="w", fa=None):
    return dict(m="st", a=x, b=y, rel=rel, bend=1, fa=fa, pl="s")

def pose(x, y, torso, arm, leg, arm2=None, leg2=None, root="hip", head=0.0, shrug=0.0, ts=1.0,
         hand_lat=0.0, hand_shift=0.0, leg_lat=0.0):
    return dict(root=root, x=x, y=y, torso=torso, head=head, shrug=shrug, ts=ts,
                arm=arm, arm2=arm2, leg=leg, leg2=leg2,
                hand_lat=hand_lat, hand_shift=hand_shift, leg_lat=leg_lat)

# ---------- props (authored in the pattern's plane) ----------

def line(*pts, w=2.0):
    return dict(k="line", pts=[list(p) for p in pts], w=w)

def dot(x, y, r=1.6):
    return dict(k="dot", pts=[[x, y]], w=r)

def rect(x, y, w, h):
    return dict(k="rect", pts=[[x, y], [w, h]], w=0)

def bench(x1, x2, top, legs=True):
    out = [rect(x1, top - 3.0, x2 - x1, 3.0)]
    if legs:
        out += [line((x1 + 3, top - 3), (x1 + 3, GROUND), w=1.6), line((x2 - 3, top - 3), (x2 - 3, GROUND), w=1.6)]
    return out

def post_bar(x, y):
    return [line((x + 9, GROUND), (x + 9, y + 3), (x, y + 3), w=1.6), dot(x, y, 1.8)]

STAND_HIP = (43.0, 43.6)

def stand_legs(ax=44.0):
    return ik(ax, GROUND + 2, 1, fa=0)

P = {}

def pat(name, view, a, b, props=(), period=2.6):
    P[name] = dict(view=view, a=a, b=b, props=list(props), period=period)

# Squat family (feet planted, hips back and down)
squat_feet = ik(46, 6, 1, fa=0)
pat("squat_back", "s",
    pose(43, 43.6, 88, ik(-4, 1, 1, rel="sh"), squat_feet),
    pose(30, 23, 52, ik(-4, 1, 1, rel="sh"), squat_feet))
pat("squat_front", "s",
    pose(43, 43.6, 89, ik(5, 0, 1, rel="sh"), squat_feet),
    pose(32, 22, 64, ik(5, 0, 1, rel="sh"), squat_feet))
pat("squat_goblet", "s",
    pose(43, 43.6, 88, ik(6, -6, -1, rel="sh"), squat_feet),
    pose(31, 22, 60, ik(6, -6, -1, rel="sh"), squat_feet))
pat("squat_bw", "s",
    pose(43, 43.6, 88, ang(-88, -86), squat_feet),
    pose(30, 23, 55, ang(5, 5), squat_feet))
pat("squat_hack", "s",
    pose(38, 42, 115, ik(3, 1, -1, rel="sh"), ik(56, 12, 1, fa=20)),
    pose(46, 25, 115, ik(3, 1, -1, rel="sh"), ik(56, 12, 1, fa=20)),
    props=[line((42.4, 23.3), (23.8, 63), w=3.2), line((50, 9.8), (67, 16), w=2.4), line((58, 12.5), (58, GROUND), w=1.6),
           line((36, 16), (36, GROUND), w=1.6)])

# Hinge family
dl_feet = ik(45, 6, 1, fa=0)
pat("deadlift", "s",
    pose(27.5, 30, 22, ang(-95, -95), dl_feet),
    pose(43, 43.6, 92, ang(-93, -93), dl_feet), period=2.8)
pat("rdl", "s",
    pose(43, 43.6, 92, ang(-93, -93), dl_feet),
    pose(30, 40, 16, ang(-104, -104), dl_feet), period=3.0)
pat("good_morning", "s",
    pose(43, 43.6, 90, ik(4, -2, -1, rel="sh"), dl_feet),
    pose(31, 41, 18, ik(4, -2, -1, rel="sh"), dl_feet), period=3.0)
pat("kb_swing", "s",
    pose(31, 38, 28, ang(-122, -122), dl_feet),
    pose(43, 43.6, 92, ang(0, 2), dl_feet), period=1.6)

# Lunges
pat("lunge", "s",
    pose(40, 41.5, 90, ang(-91, -91), ik(58, 6, 1, fa=0), leg2=ik(24, 8.5, 1, fa=-38)),
    pose(40, 26, 88, ang(-91, -91), ik(58, 6, 1, fa=0), leg2=ik(24, 8.5, 1, fa=-38)))
pat("split_squat", "s",
    pose(34, 39.5, 92, ang(-91, -91), ik(49, 6, 1, fa=0), leg2=ik(14, 20, 1, fa=188)),
    pose(33, 26, 86, ang(-91, -91), ik(49, 6, 1, fa=0), leg2=ik(14, 20, 1, fa=188)),
    props=bench(4, 22, 18))

# Leg machines
pat("leg_press", "s",
    pose(30, 20, 130, ik(2, -10, -1, rel="hip"), ik(42, 34, 1, fa=125)),
    pose(30, 20, 130, ik(2, -10, -1, rel="hip"), ik(54, 46, 1, fa=125)),
    props=[line((30, 17), (12, 38), w=3.0), line((22, 15), (40, 15), w=3.0), line((30, 15), (30, GROUND), w=1.6),
           ])
pat("leg_ext", "s",
    pose(40, 25.5, 96, ik(44, 22, -1), ang(0, -100, fa=-10)),
    pose(40, 25.5, 96, ik(44, 22, -1), ang(0, -8, fa=80)),
    props=[rect(28, 19.5, 26, 3.5), line((31, 23), (29, 52), w=3.0), line((40, 19.5), (40, GROUND), w=1.6)])
pat("leg_curl_seated", "s",
    pose(40, 25.5, 96, ik(44, 22, -1), ang(0, -8, fa=80)),
    pose(40, 25.5, 96, ik(44, 22, -1), ang(0, -112, fa=-20)),
    props=[rect(28, 19.5, 26, 3.5), line((31, 23), (29, 52), w=3.0), line((40, 19.5), (40, GROUND), w=1.6),
           line((52, 31), (62, 31), w=3.0)])
pat("leg_curl_lying", "s",
    pose(42, 23, 2, ik(80, 19, 1), ang(180, 180, fa=180)),
    pose(42, 23, 2, ik(80, 19, 1), ang(180, 75, fa=-15)),
    props=bench(22, 82, 20))
pat("calf_raise", "s",
    pose(43, 43.6, 90, ang(-92, -92), ik(44, 6, 1, fa=0)),
    pose(45.5, 47.2, 90, ang(-92, -92), ik(46.3, 9.5, 1, fa=-55)), period=1.8)
pat("calf_single", "s",
    pose(43, 43.6, 90, ang(-92, -92), ik(44, 6, 1, fa=0), leg2=ang(-98, -150, fa=-60)),
    pose(45.5, 47.2, 90, ang(-92, -92), ik(46.3, 9.5, 1, fa=-55), leg2=ang(-98, -150, fa=-60)), period=1.8)
pat("hip_thrust", "s",
    pose(20, 23, 146, ik(-1, 4, 1, rel="hip"), ik(63, 6, 1, fa=0), root="sh", head=8),
    pose(20, 23, 180, ik(-1, 4, 1, rel="hip"), ik(63, 6, 1, fa=0), root="sh", head=8),
    props=bench(2, 22, 20))
pat("glute_bridge", "s",
    pose(22, 9, 180, ang(-4, -1), ik(60, 6, 1, fa=0), root="sh"),
    pose(22, 9, 207, ang(-4, -1), ik(60, 6, 1, fa=0), root="sh", head=-27), period=2.0)
pat("back_ext", "s",
    pose(42, 36, -45, ik(-7, 1.4, -1, rel="sh"), ik(16, 10, 1, fa=-60)),
    pose(42, 36, 45, ik(-1.4, -7, -1, rel="sh"), ik(16, 10, 1, fa=-60)),
    props=[line((37, 29), (47, 39), w=4.0), line((14, 7), (24, 12), w=2.4), line((30, 20), (30, GROUND), w=1.6),
           line((20, GROUND), (44, 30), w=1.6)])

# Seats
SEAT = [rect(28, 19.5, 26, 3.5), line((31, 23), (29, 52), w=3.0), line((40, 19.5), (40, GROUND), w=1.6)]
SEAT_BACK = [rect(27, 18, 20, 3.5), line((30, 21), (29, 56), w=3.0), line((37, 18), (37, GROUND), w=1.6)]
SEAT_PAD = [rect(27, 18, 20, 3.5), line((37, 18), (37, GROUND), w=1.6), line((47, 30), (47, 52), w=3.4)]
# Front-view legs
f_legs = ik(54.5, 6, 1, fa=0)
pat("adduction", "s",
    pose(40, 25.5, 96, ik(44, 22, -1), ang(0, -90, fa=0), leg_lat=11),
    pose(40, 25.5, 96, ik(44, 22, -1), ang(0, -90, fa=0), leg_lat=1),
    props=SEAT)
pat("abduction", "s",
    pose(40, 25.5, 96, ik(44, 22, -1), ang(0, -90, fa=0), leg_lat=1),
    pose(40, 25.5, 96, ik(44, 22, -1), ang(0, -90, fa=0), leg_lat=11),
    props=SEAT)

# Pressing (lying)
lying_legs = ik(62, 6, 1, fa=0)
pat("bench_press", "s",
    pose(45, 21, 180, ik(24, 27, -1), lying_legs),
    pose(45, 21, 180, ik(22, 48, -1), lying_legs),
    props=bench(8, 52, 18))
pat("incline_press", "s",
    pose(42, 22, 145, ik(28, 40, -1), ik(60, 6, 1, fa=0)),
    pose(42, 22, 145, ik(24, 63, -1), ik(60, 6, 1, fa=0)),
    props=[line((40, 18), (14, 36), w=3.2), line((36, 18), (52, 18), w=3.2), line((40, 18), (40, GROUND), w=1.6)])
pat("floor_press", "s",
    pose(45, 8, 180, ik(24, 15, -1), lying_legs),
    pose(45, 8, 180, ik(21, 35, -1), lying_legs))
pat("skullcrusher", "s",
    pose(45, 21, 180, ang(100, 100), lying_legs),
    pose(45, 21, 180, ang(102, 205), lying_legs),
    props=bench(8, 52, 18), period=2.4)
pat("fly_lying", "s",
    pose(45, 21, 180, ik(26, 1, -1, rel="sh", pl="f"), lying_legs),
    pose(45, 21, 180, ik(-6, 26, -1, rel="sh", pl="f"), lying_legs),
    props=bench(8, 52, 18), period=2.8)
pat("fly_standing", "s",
    pose(43, 43.6, 90, ik(26, -4, -1, rel="sh", pl="h"), stand_legs()),
    pose(43, 43.6, 90, ik(-5, 22, -1, rel="sh", pl="h"), stand_legs()), period=2.6)
pat("pec_deck", "s",
    pose(38, 24, 92, ik(25, 3, -1, rel="sh", pl="h"), ik(56, 6, 1, fa=0)),
    pose(38, 24, 92, ik(-5, 22, -1, rel="sh", pl="h"), ik(56, 6, 1, fa=0)),
    props=SEAT_BACK)

# Pressing (seated / standing)
pat("seated_press", "s",
    pose(35, 24, 95, ik(5, -3, -1, rel="sh"), ik(55, 6, 1, fa=0)),
    pose(35, 24, 95, ik(24, -2, -1, rel="sh"), ik(55, 6, 1, fa=0)),
    props=[rect(24, 18, 20, 3.5), line((27, 21), (25, 56), w=3.0), line((34, 18), (34, GROUND), w=1.6)])
pat("standing_press_fwd", "s",
    pose(43, 43.6, 90, ik(4, -4, -1, rel="sh"), stand_legs()),
    pose(43, 43.6, 90, ik(24, -2, -1, rel="sh"), stand_legs()))
pat("overhead_press", "s",
    pose(43, 43.6, 90, ik(4, 0, -1, rel="sh"), stand_legs()),
    pose(43, 43.6, 90, ik(1, 27, -1, rel="sh"), stand_legs()))
pat("seated_overhead", "s",
    pose(38, 24, 92, ik(4, 0, -1, rel="sh"), ik(56, 6, 1, fa=0)),
    pose(38, 24, 92, ik(1, 27, -1, rel="sh"), ik(56, 6, 1, fa=0)),
    props=[rect(27, 18, 20, 3.5), line((30, 21), (29, 56), w=3.0), line((37, 18), (37, GROUND), w=1.6)])
pat("pushup", "s",
    pose(41, 21.7, 22, ik(64, 6, -1), ik(6, 7.5, 1, fa=-35)),
    pose(43.9, 10.2, 4, ik(64, 6, -1), ik(6, 7.5, 1, fa=-35)), period=2.0)
pat("pike_pushup", "s",
    pose(38, 44, -38.7, ik(59, 6, -1), ik(30, 7.5, 1, fa=-35)),
    pose(40, 37, -54.5, ik(59, 6, -1), ik(30, 7.5, 1, fa=-35)), period=2.2)
pat("dips", "s",
    pose(49, 76, 78, ik(50, 51, -1), ang(-100, -150, fa=-60), root="sh"),
    pose(51, 61, 68, ik(50, 51, -1), ang(-95, -150, fa=-60), root="sh"),
    props=post_bar(50, 49.5), period=2.2)

# Shoulders / raises (front view)
f_arm_down = ang(-84, -84)
pat("lateral_raise", "s",
    pose(43, 43.6, 90, ang(-84, -82, pl="f"), stand_legs()),
    pose(43, 43.6, 90, ang(2, 8, pl="f"), stand_legs()), period=2.4)
pat("lateral_one", "s",
    pose(43, 43.6, 90, ang(-84, -82, pl="f"), stand_legs(), arm2=ang(-93, -95, pl="f")),
    pose(43, 43.6, 90, ang(2, 8, pl="f"), stand_legs(), arm2=ang(-93, -95, pl="f")), period=2.4)
pat("rear_fly", "s",
    pose(33, 41, 24, ang(-90, -90, pl="f"), ik(45, 6, 1, fa=0)),
    pose(33, 41, 24, ang(-4, 4, pl="f"), ik(45, 6, 1, fa=0)), period=2.4)
pat("rear_fly_machine", "s",
    pose(38, 24, 88, ik(-5, 22, -1, rel="sh", pl="h"), ik(56, 6, 1, fa=0)),
    pose(38, 24, 88, ik(26, -2, -1, rel="sh", pl="h"), ik(56, 6, 1, fa=0)),
    props=SEAT_PAD)
pat("pull_apart", "s",
    pose(43, 43.6, 90, ik(-5, 26, -1, rel="sh", pl="h"), stand_legs()),
    pose(43, 43.6, 90, ik(27, 0, -1, rel="sh", pl="h"), stand_legs()), period=2.0)
pat("face_pull", "s",
    pose(42, 43.6, 88, ik(24, 0, 1, rel="sh"), stand_legs(43)),
    pose(42, 43.6, 88, ik(2, 6, 1, rel="sh"), stand_legs(43)))
pat("shrug", "s",
    pose(43, 43.6, 90, ang(-90, -90), stand_legs()),
    pose(43, 43.6, 90, ang(-90, -90), stand_legs(), shrug=3.2), period=1.8)

# Arms
pat("curl", "s",
    pose(43, 43.6, 90, ang(-92, -86), stand_legs()),
    pose(43, 43.6, 90, ang(-86, 100), stand_legs()), period=2.2)
pat("preacher_curl", "s",
    pose(36, 25, 98, ang(-42, -20), ik(55, 6, 1, fa=0)),
    pose(36, 25, 98, ang(-42, 100), ik(55, 6, 1, fa=0)),
    props=[rect(25, 19, 20, 3.5), line((40, 46), (52, 35), w=3.6), line((46, 40), (46, GROUND), w=1.6)], period=2.2)
pat("pushdown", "s",
    pose(42, 43.6, 85, ang(-95, 40), stand_legs(43)),
    pose(42, 43.6, 85, ang(-94, -88), stand_legs(43)), period=2.0)
pat("overhead_ext", "s",
    pose(43, 43.6, 90, ang(95, 250), stand_legs()),
    pose(43, 43.6, 90, ang(95, 96), stand_legs()), period=2.4)

# Pulling
pat("pullup", "s",
    pose(49, 66.5, 92, ik(50, 93, -1), ang(-96, -125, fa=-40), root="sh"),
    pose(43, 87, 100, ik(50, 93, -1), ang(-96, -125, fa=-40), root="sh"),
    props=post_bar(50, 93), period=2.4)
pat("pullup_assisted", "s",
    pose(49, 66.5, 92, ik(50, 93, -1), ang(-80, -170, fa=-80), root="sh"),
    pose(43, 87, 100, ik(50, 93, -1), ang(-80, -170, fa=-80), root="sh"),
    props=post_bar(50, 93) + [line((30, 24), (46, 24), w=3.0), line((38, 24), (38, GROUND), w=1.6)], period=2.4)
pat("pulldown", "s",
    pose(40, 25.5, 95, ik(6, 26, -1, rel="sh"), ang(-3, -90, fa=0)),
    pose(40, 25.5, 100, ik(5, -1.5, -1, rel="sh"), ang(-3, -90, fa=0)),
    props=[rect(30, 19.5, 22, 3.5), line((40, 19.5), (40, GROUND), w=1.6), line((54, 28.5), (64, 28.5), w=3.0)])
pat("pulldown_kneel", "s",
    pose(40, 25, 92, ik(6, 26, -1, rel="sh"), ang(-90, 180, fa=180)),
    pose(40, 25, 96, ik(5, -1.5, -1, rel="sh"), ang(-90, 180, fa=180)))
pat("bent_row", "s",
    pose(34, 40, 30, ik(55, 28, -1), ik(45, 6, 1, fa=0)),
    pose(34, 40, 30, ik(44, 37, -1), ik(45, 6, 1, fa=0)), period=2.2)
pat("one_arm_row", "s",
    pose(36, 42, 5, ik(61, 20, -1), ik(24, 6, 1, fa=0), arm2=ik(63, 23, -1), leg2=ang(-90, 180, fa=180)),
    pose(36, 42, 5, ik(46, 39, -1), ik(24, 6, 1, fa=0), arm2=ik(63, 23, -1), leg2=ang(-90, 180, fa=180)),
    props=bench(30, 76, 22), period=2.2)
pat("seated_row", "s",
    pose(30, 14, 72, ik(62, 34, -1), ik(62, 10, 1, fa=80)),
    pose(30, 14, 95, ik(34, 30, -1), ik(62, 10, 1, fa=80)),
    props=[rect(20, 8, 18, 3), line((64, 6), (64, 18), w=2.4)], period=2.4)
pat("chest_row", "s",
    pose(36, 25, 85, ik(24, -3, -1, rel="sh"), ik(55, 6, 1, fa=0)),
    pose(36, 25, 85, ik(1, -4, -1, rel="sh"), ik(55, 6, 1, fa=0)),
    props=[rect(25, 19, 20, 3.5), line((35, 19), (35, GROUND), w=1.6), line((44, 30), (44, 50), w=3.4)], period=2.4)

# Core
pat("hanging_leg_raise", "s",
    pose(50, 69.5, 90, ik(50, 96, -1), ang(-90, -90, fa=-10), root="sh"),
    pose(50, 69.5, 100, ik(50, 96, -1), ang(-5, -5, fa=80), root="sh"),
    props=post_bar(50, 96), period=2.6)
pat("cable_crunch", "s",
    pose(40, 25, 78, ik(4, 2, -1, rel="hd"), ang(-90, 180, fa=180)),
    pose(40, 25, 22, ik(4, 2, -1, rel="hd"), ang(-90, 180, fa=180)), period=2.2)
pat("crunch", "s",
    pose(45, 8, 180, ik(2, -1, -1, rel="hd"), ik(62, 6, 1, fa=0)),
    pose(45, 8, 152, ik(2, -1, -1, rel="hd"), ik(62, 6, 1, fa=0)), period=1.8)
pat("ab_machine", "s",
    pose(38, 24, 96, ik(4, 0, -1, rel="hd"), ik(56, 6, 1, fa=0)),
    pose(38, 24, 55, ik(4, 0, -1, rel="hd"), ik(56, 6, 1, fa=0)),
    props=[rect(27, 18, 20, 3.5), line((37, 18), (37, GROUND), w=1.6)], period=2.2)
pat("dead_bug", "s",
    pose(52, 8, 180, ang(90, 90), ang(90, 0, fa=90), leg2=ang(90, 0, fa=90)),
    pose(52, 8, 180, ang(172, 178), ang(90, 0, fa=90), arm2=ang(90, 90), leg2=ang(12, 8, fa=90)),
    period=2.8)
pat("russian_twist", "s",
    pose(40, 12, 125, ik(13, -9, -1, rel="sh"), ang(42, -12, fa=0), hand_shift=-12),
    pose(40, 12, 125, ik(13, -9, -1, rel="sh"), ang(42, -12, fa=0), hand_shift=12), period=1.6)
pat("pallof", "s",
    pose(43, 43.6, 90, ik(5, -8, -1, rel="sh"), stand_legs()),
    pose(43, 43.6, 90, ik(24, -5, -1, rel="sh"), stand_legs()), period=2.4)
pat("windmill", "f",
    pose(50, 42, 90, ang(90, 90), ik(60, 6, 1, fa=0), arm2=ang(-90, -90)),
    pose(50, 42, 142, ang(90, 90), ik(60, 6, 1, fa=0), arm2=ang(-100, -100)), period=3.0)
pat("copenhagen", "f",
    pose(40, 14, 28, ang(-90, 0), st(10, 13, fa=180), leg2=st(4, 24, fa=180), arm2=ik(6, 4, 1, rel="hip")),
    pose(40, 19.7, 15, ang(-90, 0), st(10, 13, fa=180), leg2=st(4, 24, fa=180), arm2=ik(6, 4, 1, rel="hip")),
    props=bench(0, 15, 21), period=2.6)

# Core holds and rollouts
# Forearm plank: elbows under shoulders, body in one line; the B pose is a slight breath.
pat("plank", "s",
    pose(40, 15.2, 10, ang(-90, 0), st(3.8, 6.5, fa=-35)),
    pose(40, 15.9, 11, ang(-90, 0), st(3.8, 6.5, fa=-35)), period=3.0)
pat("side_plank", "f",
    pose(41.6, 20.2, 15.5, ang(-90, 0), st(5, 10, fa=180), leg2=st(5, 10, fa=180), arm2=ik(6, 4, 1, rel="hip")),
    pose(41.6, 21.2, 16.4, ang(-90, 0), st(5, 10, fa=180), leg2=st(5, 10, fa=180), arm2=ik(6, 4, 1, rel="hip")),
    period=3.0)
pat("hollow_hold", "s",
    pose(52, 8, 166, ang(168, 172), ang(14, 14, fa=90), leg2=ang(14, 14, fa=90)),
    pose(52, 8, 162, ang(164, 168), ang(18, 18, fa=90), leg2=ang(18, 18, fa=90)), period=3.0)
pat("ab_wheel", "s",
    pose(34, 24.6, 25, ang(-88, -88), ang(-102, 180, fa=180)),
    pose(47.2, 14, 8, ang(-25, -25), ang(-155, 180, fa=180)), period=3.0)
pat("hanging_knee_raise", "s",
    pose(50, 69.5, 90, ik(50, 96, -1), ang(-90, -90, fa=-10), root="sh"),
    pose(50, 69.5, 96, ik(50, 96, -1), ang(8, -82, fa=0), root="sh"),
    props=post_bar(50, 96), period=2.4)

# Calisthenics progressions
pat("incline_pushup", "s",
    pose(33.1, 30.9, 40, ik(64, 23.5, -1), st(4, 6.5, fa=-35)),
    pose(36.9, 25.5, 30, ik(64, 23.5, -1), st(4, 6.5, fa=-35)),
    props=bench(58, 80, 22), period=2.0)
pat("knee_pushup", "s",
    pose(34.7, 18.1, 39.4, ik(57, 7.5, -1), ang(-140.6, 180, fa=180)),
    pose(38.1, 11.9, 18, ik(57, 7.5, -1), ang(-162, 180, fa=180)), period=2.0)
pat("inverted_row", "s",
    pose(39.9, 18.4, 19, ik(64, 52, -1), st(4, 6, fa=60)),
    pose(34.3, 28.9, 37, ik(64, 52, -1), st(4, 6, fa=60)),
    props=post_bar(64, 52), period=2.4)
pat("dead_hang", "s",
    pose(49.5, 70, 91, ik(50, 95, -1), ang(-92, -92, fa=-10), root="sh"),
    pose(49.5, 71.5, 91, ik(50, 95, -1), ang(-92, -92, fa=-10), root="sh"),
    props=post_bar(50, 95), period=3.0)
pat("bench_dip", "s",
    pose(44, 49, 90, ik(40, 23.5, -1), ik(66, 6, 1, fa=0), root="sh"),
    pose(45, 37, 90, ik(40, 23.5, -1), ik(66, 6, 1, fa=0), root="sh"),
    props=bench(18, 40, 22), period=2.2)
pat("l_sit", "s",
    pose(40, 14, 92, ang(-90, -90), ang(0, 0, fa=90)),
    pose(40, 14.6, 92, ang(-90, -90), ang(5, 5, fa=90)),
    props=[line((34, GROUND), (34, 12)), line((47, GROUND), (47, 12)), line((31, 12.5), (50, 12.5), w=2.4)], period=3.0)
pat("pistol_squat", "s",
    pose(43, 43.6, 90, ang(0, 0), stand_legs(), leg2=ang(-72, -72, fa=0)),
    pose(34, 16, 50, ang(5, 5), ik(46, 6, 1, fa=0), leg2=ang(4, 4, fa=90)), period=3.0)

# ---------- looping cardio patterns (a full gait cycle instead of A <-> B) ----------
LOOP_FRAMES = 25

def loop_pat(name, gen, props=(), period=1.2):
    P[name] = dict(view="s", a=gen(0.0), b=gen(0.5), props=list(props), period=period, gen=gen, loop=True)

def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)

DECK = 9.0  # treadmill belt height

def treadmill_props(incline=0.0):
    rise = math.tan(math.radians(incline))
    y0, y1 = DECK - 1.5 + (18 - 45) * rise, DECK - 1.5 + (74 - 45) * rise
    return [line((18, y0), (74, y1), w=3.0), line((20, GROUND), (20, y0 - 1)), line((70, GROUND), (70, y1 - 1)),
            line((72, y1), (68, 66), w=1.6), rect(62, 64, 12, 4), line((66, 54), (52, 54), w=1.2)]

def gait(t, run=False, incline=0.0):
    rise = math.tan(math.radians(incline))
    bob = (1.4 if run else 0.7) * math.cos(4 * math.pi * t)
    hip = (45.0, (46.4 if run else 47.6) + bob)
    legs = []
    for ph in (t, t + 0.5):
        p = ph % 1.0
        stance = 0.42 if run else 0.6
        front, back = (55.0, 37.0) if run else (55.0, 35.0)
        if p < stance:
            s_ = p / stance
            x = front + (back - front) * s_
            lift = 0.0
            fa = -12 * smooth((s_ - 0.75) / 0.25)
        else:
            s_ = smooth((p - stance) / (1 - stance))
            kick = (9.0 * math.sin(math.pi * s_) if run else 0.0)
            x = back + (front - back) * s_ - kick * (1 - s_)
            lift = (11.0 if run else 4.5) * math.sin(math.pi * s_)
            fa = -22 * (1 - s_) + 10 * s_ * (1 - s_)
        y = DECK + 2 + (x - 45) * rise + lift
        legs.append(ik(x, y, 1, fa=fa))
    arms = []
    for ph in (t + 0.5, t):
        sw = math.sin(2 * math.pi * ph)
        if run:
            arms.append(ang(-95 + 38 * sw, -5 + 38 * sw + 70))
        else:
            arms.append(ang(-92 + 22 * sw, -86 + 28 * sw))
    torso = (80.0 if run else 87.0) + incline * 0.4
    return pose(hip[0], hip[1], torso, arms[0], legs[0], arm2=arms[1], leg2=legs[1], head=(-4 if run else 0))

def elliptical(t):
    legs = []
    for ph in (t, t + 0.5):
        th = 2 * math.pi * ph
        x = 46 + 9.5 * math.cos(th)
        y = 16 + 3.2 * math.sin(th)
        legs.append(ik(x, y, 1, fa=-8 * math.sin(th)))
    arms = []
    for ph in (t + 0.5, t):
        th = 2 * math.pi * ph
        arms.append(ik(56 + 6.5 * math.cos(th), 57 + 1.5 * math.sin(th), -1))
    return pose(43.5, 50.2 + 0.6 * math.sin(4 * math.pi * t), 86, arms[0], legs[0], arm2=arms[1], leg2=legs[1])

ELLIPTICAL_PROPS = [line((28, GROUND + 1), (74, GROUND + 1), w=3.0), line((72, GROUND + 1), (66, 72), w=1.6),
                    rect(61, 70, 11, 5), line((34, GROUND + 1), (34, 9)), line((58, GROUND + 1), (58, 9))]

loop_pat("treadmill_walk", lambda t: gait(t, incline=6.0), treadmill_props(6.0), period=1.15)
loop_pat("treadmill_run", lambda t: gait(t, run=True), treadmill_props(0.0), period=0.75)
loop_pat("elliptical", elliptical, ELLIPTICAL_PROPS, period=1.3)

# ---------- implements ----------

def imp(t, hands="both", anchor=None, at="hands"):
    return dict(t=t, hands=hands, anchor=anchor, at=at)

BB, DB, KB = imp("barbell"), imp("dumbbell"), imp("kettlebell", hands="center")
NONE = []

def cable(x, y, hands="both", out=None):
    """Anchor at world x/y. `out` = lateral distance outward from the hand's side (None = same as the hand)."""
    return imp("cable", hands=hands, anchor=[x, y, out])

def band(x=None, y=None, hands="both", out=None):
    return imp("band", hands=hands, anchor=([x, y, out] if x is not None else "foot"))

HANDLE = imp("handle")
SMITH_RAILS = [line((62, GROUND), (62, 96), w=1.2), line((66, GROUND), (66, 96), w=1.2)]

# exercise id -> (pattern, implements, extra props)
EX = {
    # chest
    "bb_bench": ("bench_press", [BB]), "bb_incline": ("incline_press", [BB]),
    "db_bench": ("bench_press", [DB]), "db_incline": ("incline_press", [DB]),
    "db_floor_press": ("floor_press", [DB]), "db_fly": ("fly_lying", [DB]),
    "cable_fly": ("fly_standing", [cable(38, 90, out=26)]), "machine_chest": ("seated_press", [HANDLE]),
    "pec_deck": ("pec_deck", [HANDLE]), "smith_bench": ("bench_press", [BB], "smith"),
    "pushup": ("pushup", NONE), "band_press": ("standing_press_fwd", [band(14, 66)]),
    "dips": ("dips", NONE),
    # shoulders
    "bb_ohp": ("overhead_press", [BB]), "db_ohp": ("overhead_press", [DB]),
    "kb_press": ("overhead_press", [imp("kettlebell")]), "machine_shoulder": ("seated_overhead", [HANDLE]),
    "pike_pushup": ("pike_pushup", NONE), "db_lateral": ("lateral_raise", [DB]),
    "cable_lateral": ("lateral_one", [cable(43, 8, hands="near", out=-16)]), "band_lateral": ("lateral_raise", [band()]),
    "db_rear_fly": ("rear_fly", [DB]), "reverse_fly_machine": ("rear_fly_machine", [HANDLE]),
    "face_pull": ("face_pull", [cable(92, 72)]), "band_pull_apart": ("pull_apart", [imp("band", anchor="hands")]),
    # arms
    "pushdown": ("pushdown", [cable(62, 96)]), "skullcrusher": ("skullcrusher", [BB]),
    "db_oh_ext": ("overhead_ext", [imp("dumbbell", hands="center")]),
    "close_grip_bench": ("bench_press", [BB]), "band_pushdown": ("pushdown", [band(62, 96)]),
    "diamond_pushup": ("pushup", NONE), "bb_curl": ("curl", [BB]), "db_curl": ("curl", [DB]),
    "hammer_curl": ("curl", [DB]), "cable_curl": ("curl", [cable(62, 6)]), "band_curl": ("curl", [band()]),
    "kb_curl": ("curl", [imp("kettlebell", hands="near")]), "preacher_curl": ("preacher_curl", [HANDLE]),
    # back
    "pullup": ("pullup", NONE), "chinup": ("pullup", NONE), "assisted_pullup": ("pullup_assisted", NONE),
    "lat_pulldown": ("pulldown", [cable(46, 99)]), "band_pulldown": ("pulldown_kneel", [band(46, 99)]),
    "bb_row": ("bent_row", [BB]), "db_row": ("one_arm_row", [imp("dumbbell", hands="near")]),
    "kb_row": ("bent_row", [imp("kettlebell", hands="near")]), "cable_row": ("seated_row", [cable(90, 30)]),
    "machine_row": ("chest_row", [HANDLE]), "band_row": ("seated_row", [band(90, 30)]),
    "db_shrug": ("shrug", [DB]), "bb_shrug": ("shrug", [BB]), "back_ext": ("back_ext", NONE),
    # legs
    "back_squat": ("squat_back", [BB]), "front_squat": ("squat_front", [BB]),
    "goblet_squat": ("squat_goblet", [imp("dumbbell", hands="center")]), "kb_goblet": ("squat_goblet", [KB]),
    "smith_squat": ("squat_back", [BB], "smith"), "hack_squat": ("squat_hack", NONE),
    "leg_press": ("leg_press", [imp("sled", at="foot")]), "split_squat": ("split_squat", [DB]),
    "db_lunge": ("lunge", [DB]), "bw_squat": ("squat_bw", NONE), "bw_lunge": ("lunge", NONE),
    "leg_ext": ("leg_ext", [imp("pad", at="ankle")]), "deadlift": ("deadlift", [BB]),
    "bb_rdl": ("rdl", [BB]), "db_rdl": ("rdl", [DB]), "kb_swing": ("kb_swing", [KB]),
    "leg_curl": ("leg_curl_lying", [imp("pad", at="ankle")]), "seated_leg_curl": ("leg_curl_seated", [imp("pad", at="ankle")]),
    "band_good_morning": ("good_morning", [band()]), "hip_thrust": ("hip_thrust", [BB]),
    "glute_bridge": ("glute_bridge", NONE), "adductor_machine": ("adduction", NONE),
    "abductor_machine": ("abduction", NONE), "copenhagen": ("copenhagen", NONE),
    "calf_machine": ("calf_raise", [imp("pad", at="shoulder")]), "db_calf": ("calf_raise", [DB]),
    "bw_calf": ("calf_single", NONE),
    # core
    "hanging_leg_raise": ("hanging_leg_raise", NONE), "cable_crunch": ("cable_crunch", [cable(58, 98)]),
    "crunch": ("crunch", NONE), "ab_crunch_machine": ("ab_machine", [HANDLE]), "dead_bug": ("dead_bug", NONE),
    "russian_twist": ("russian_twist", NONE), "pallof": ("pallof", [HANDLE]), "band_pallof": ("pallof", [HANDLE]),
    "kb_windmill": ("windmill", [imp("kettlebell", hands="near")]),
    "knee_pushup": ("knee_pushup", NONE), "incline_pushup": ("incline_pushup", NONE), "archer_pushup": ("pushup", NONE),
    "inverted_row": ("inverted_row", NONE), "negative_pullup": ("pullup", NONE), "dead_hang": ("dead_hang", NONE),
    "bench_dip": ("bench_dip", NONE), "l_sit": ("l_sit", NONE), "bw_split_squat": ("split_squat", NONE),
    "pistol_squat": ("pistol_squat", NONE),
    "plank": ("plank", NONE), "side_plank": ("side_plank", NONE), "hollow_hold": ("hollow_hold", NONE),
    "ab_wheel": ("ab_wheel", [imp("wheel", hands="center")]), "hanging_knee_raise": ("hanging_knee_raise", NONE),
    # cardio
    "tm_walk": ("treadmill_walk", NONE), "tm_run": ("treadmill_run", NONE), "tm_intervals": ("treadmill_run", NONE),
    "ell_steady": ("elliptical", [cable(66, 70), imp("pedal")]), "ell_intervals": ("elliptical", [cable(66, 70), imp("pedal")]),
}

# ---------- form cues ----------
CUES = {
    "treadmill_walk": ["Walk tall, don't hold the handrails", "Short, quick steps uphill", "Land under your hips, push off your toes", "Breathe steadily — you should still be able to talk"],
    "treadmill_run": ["Run tall with a slight forward lean", "Land under your hips, not out in front", "Elbows at 90°, swing front to back", "Use the safety clip on your clothing"],
    "elliptical": ["Stand tall, weight through your heels", "Push and pull the handles to use your arms", "Keep a smooth, steady rhythm", "Turn up resistance before speed"],
    "squat_back": ["Bar on upper back, feet shoulder-width", "Break at hips and knees together", "Knees track over toes", "Stand up driving through mid-foot"],
    "squat_front": ["Bar on front of shoulders, elbows high", "Stay tall — chest up the whole way", "Sit straight down between your heels", "Drive up keeping elbows up"],
    "squat_goblet": ["Hold the weight at your chest", "Elbows inside the knees at the bottom", "Keep your chest up", "Push the floor away to stand"],
    "squat_bw": ["Feet shoulder-width, toes slightly out", "Reach arms forward as you sit back", "Go as low as you can with a flat back", "Squeeze glutes at the top"],
    "squat_hack": ["Back and shoulders flat on the pads", "Feet mid-platform, shoulder-width", "Lower until thighs are parallel", "Don't lock knees hard at the top"],
    "deadlift": ["Bar over mid-foot, shins close", "Flat back, chest up, arms long", "Push the floor away; bar stays on legs", "Finish tall — don't lean back"],
    "rdl": ["Soft knees, push hips straight back", "Bar slides down close to the legs", "Stop when hamstrings are stretched", "Squeeze glutes to stand"],
    "good_morning": ["Band or weight across upper back", "Soft knees, hinge hips back", "Keep back flat, chest proud", "Stop at a deep hamstring stretch"],
    "kb_swing": ["Hike the bell back between your legs", "Snap hips forward — arms just guide", "Bell floats to chest height", "Brace abs and squeeze glutes at the top"],
    "lunge": ["Long step, torso tall", "Lower until back knee nearly touches", "Front knee stays over the foot", "Push through the front heel"],
    "split_squat": ["Rear foot laces-down on the bench", "Most weight on the front leg", "Drop straight down, torso tall", "Drive up through the front heel"],
    "leg_press": ["Back and hips flat on the seat", "Feet shoulder-width on the plate", "Lower until knees reach ~90°", "Press without locking out knees"],
    "leg_ext": ["Knee lined up with the machine pivot", "Pad just above the ankles", "Straighten fully, squeeze quads", "Lower slowly"],
    "leg_curl_seated": ["Knee lined up with the pivot", "Thigh pad snug", "Curl heels down and back", "Control the return"],
    "leg_curl_lying": ["Hips pressed into the pad", "Pad just above the heels", "Curl up without lifting hips", "Lower slowly to straight"],
    "calf_raise": ["Balls of feet on the platform", "Lower heels for a full stretch", "Rise as high as possible", "Pause at the top"],
    "calf_single": ["Hold something for balance", "Full stretch at the bottom", "Rise onto the big toe", "Slow on the way down"],
    "hip_thrust": ["Upper back on the bench edge", "Feet flat, shins vertical at the top", "Tuck chin, drive hips up", "Squeeze glutes hard at the top"],
    "glute_bridge": ["Feet flat, close to your hips", "Brace abs, press through heels", "Lift until body is a straight line", "Squeeze glutes, lower slowly"],
    "back_ext": ["Pad just below the hip bones", "Hinge down with a flat back", "Rise until body is in line", "Don't over-arch at the top"],
    "adduction": ["Sit tall against the back pad", "Pads on the inside of the knees", "Squeeze legs together", "Open slowly"],
    "abduction": ["Sit tall against the back pad", "Pads on the outside of the knees", "Push knees out", "Return slowly"],
    "bench_press": ["Shoulder blades pinched, feet planted", "Lower to mid-chest, elbows ~45°", "Touch lightly, don't bounce", "Press up and slightly back"],
    "incline_press": ["Bench at 30–45°", "Lower to upper chest", "Elbows slightly tucked", "Press straight up over shoulders"],
    "floor_press": ["Lie with knees bent, feet flat", "Lower until upper arms touch the floor", "Pause, then press", "Keep wrists over elbows"],
    "skullcrusher": ["Upper arms vertical, still", "Bend only at the elbows", "Lower toward forehead / behind head", "Extend fully, squeeze triceps"],
    "fly_lying": ["Slight bend in the elbows, keep it fixed", "Open arms wide in an arc", "Stop at a chest stretch", "Hug back up over the chest"],
    "fly_standing": ["Step forward, slight lean", "Soft elbows, wide arc", "Bring hands together in front", "Return under control"],
    "pec_deck": ["Seat so handles are at chest height", "Soft elbows", "Squeeze arms together in front", "Open slowly to a stretch"],
    "seated_press": ["Handles at mid-chest height", "Back flat on the pad", "Press out without locking elbows", "Control the return"],
    "standing_press_fwd": ["Band anchored behind you", "Brace abs, staggered stance helps", "Press straight forward", "Return slowly"],
    "overhead_press": ["Squeeze glutes and abs", "Start at the front of the shoulders", "Press straight up, head through", "Finish over the middle of your feet"],
    "seated_overhead": ["Back flat on the pad", "Handles at shoulder height", "Press up without shrugging", "Lower to shoulder level"],
    "pushup": ["Hands under shoulders, body in a line", "Lower chest to just above the floor", "Elbows ~45° from your body", "Push the floor away"],
    "pike_pushup": ["Hips high in an upside-down V", "Lower the top of your head toward the floor", "Elbows track back", "Press back up"],
    "dips": ["Start with arms straight, shoulders down", "Lean slightly forward", "Lower until upper arms are parallel", "Press up to straight arms"],
    "lateral_raise": ["Slight bend in elbows", "Lead with the elbows", "Raise to shoulder height", "Lower slowly — no swinging"],
    "lateral_one": ["Stand side-on to the cable", "Raise to shoulder height", "Keep torso still", "Lower slowly"],
    "rear_fly": ["Hinge forward, flat back", "Arms hang under the shoulders", "Raise out to the sides", "Squeeze shoulder blades"],
    "rear_fly_machine": ["Chest against the pad", "Arms straight, slight elbow bend", "Sweep arms back and out", "Return slowly"],
    "pull_apart": ["Arms straight at shoulder height", "Pull the band apart to your chest", "Squeeze shoulder blades", "Return with control"],
    "face_pull": ["Rope at face height", "Pull to your forehead, elbows high", "Rotate hands back at the end", "Return slowly"],
    "shrug": ["Arms straight, weight at your sides", "Lift shoulders toward ears", "Pause at the top", "Lower fully"],
    "curl": ["Elbows pinned at your sides", "Curl without swinging", "Squeeze at the top", "Lower all the way"],
    "preacher_curl": ["Armpits snug on the pad", "Curl up, keep upper arms down", "Squeeze at the top", "Lower until almost straight"],
    "pushdown": ["Elbows pinned to your sides", "Push down until arms are straight", "Squeeze triceps", "Let forearms rise to parallel"],
    "overhead_ext": ["Hold the weight overhead", "Elbows point up, stay close", "Lower behind your head", "Extend to straight"],
    "pullup": ["Hang with straight arms, shoulders down", "Pull elbows down to your ribs", "Chin over the bar", "Lower all the way"],
    "pullup_assisted": ["Knees on the pad", "Pull elbows down to your ribs", "Chin over the bar", "Lower to straight arms"],
    "pulldown": ["Thighs snug under the pad", "Lean back slightly", "Pull bar to upper chest, elbows down", "Let arms straighten fully"],
    "pulldown_kneel": ["Band anchored high", "Kneel tall, brace abs", "Pull elbows down to your sides", "Return slowly"],
    "bent_row": ["Hinge to ~45°, flat back", "Pull to the lower ribs", "Elbows travel back", "Lower to straight arms"],
    "one_arm_row": ["Hand and knee on the bench, flat back", "Pull the weight to your hip", "Elbow goes back, not out", "Lower to full stretch"],
    "seated_row": ["Sit tall, knees soft", "Pull handle to your belly", "Squeeze shoulder blades", "Reach forward without rounding"],
    "chest_row": ["Chest on the pad", "Pull handles back to your sides", "Squeeze shoulder blades", "Return to straight arms"],
    "hanging_leg_raise": ["Hang still, shoulders engaged", "Lift legs with abs, not momentum", "Raise to hip height or higher", "Lower slowly"],
    "cable_crunch": ["Kneel, rope beside your head", "Curl ribs toward hips", "Hips stay still", "Return slowly"],
    "crunch": ["Knees bent, lower back down", "Curl shoulders off the floor", "Don't pull on your neck", "Lower slowly"],
    "ab_machine": ["Feet secured, chest on pads", "Curl forward using abs", "Exhale at the bottom", "Return under control"],
    "dead_bug": ["Lower back pressed to the floor", "Extend opposite arm and leg", "Move slowly", "Alternate sides"],
    "russian_twist": ["Lean back, chest up", "Rotate side to side", "Move from the ribs, not just arms", "Feet down to make it easier"],
    "pallof": ["Stand side-on to the cable/band", "Press straight out from the chest", "Don't let it twist you", "Bring back to chest slowly"],
    "windmill": ["Weight locked out overhead", "Push hips to the side", "Reach down the front leg", "Eyes on the weight"],
    "incline_pushup": ["Hands on a bench, body in a line", "Lower chest to the edge", "Elbows ~45° from your body", "Push away; lower surface = harder"],
    "knee_pushup": ["Knees down, hips in line with shoulders", "Lower chest to just above the floor", "Elbows ~45° from your body", "Push the floor away"],
    "inverted_row": ["Hang under a low bar or sturdy table", "Heels down, body straight", "Pull chest to the bar", "Lower all the way"],
    "dead_hang": ["Grip the bar, arms straight", "Pull shoulders slightly down", "Legs still, breathe", "Hold for time"],
    "bench_dip": ["Hands on the bench edge behind you", "Hips close to the bench", "Lower until upper arms are level", "Press back up"],
    "l_sit": ["Hands beside your hips, arms locked", "Push down, lift your hips", "Legs straight out in front", "Tuck knees to make it easier"],
    "pistol_squat": ["Stand on one leg, other leg forward", "Sit back and down slowly", "Hold a post for balance if needed", "Drive up through the heel"],
    "plank": ["Elbows under shoulders", "Squeeze glutes, ribs down", "Head to heels in one line", "Breathe — don't let hips sag"],
    "side_plank": ["Elbow under shoulder", "Feet stacked", "Lift hips into a straight line", "Don't let hips drop or roll"],
    "hollow_hold": ["Lower back pressed to the floor", "Lift shoulders and legs slightly", "Arms overhead, legs straight", "Bend knees to make it easier"],
    "ab_wheel": ["Start on knees, wheel under shoulders", "Brace abs, tuck pelvis", "Roll out as far as you can keep a flat back", "Pull back with your abs"],
    "hanging_knee_raise": ["Hang still, shoulders engaged", "Bring knees up to your chest", "Curl the pelvis at the top", "Lower slowly, no swinging"],
    "copenhagen": ["Top leg on the bench", "Forearm under shoulder", "Lift hips into a straight line", "Hold or pulse slowly"],
}
EX_TIPS = {
    "tm_intervals": "Alternate 1 minute fast with 2 minutes easy. Change speed with the buttons, not by grabbing the rails.",
    "ell_intervals": "Alternate 1 minute at high resistance with 2 minutes easy.",
    "tm_walk": "Incline does the work here — keep the speed comfortable.",
    "close_grip_bench": "Hands shoulder-width; keep elbows tucked.",
    "chinup": "Palms facing you — more biceps.",
    "hammer_curl": "Palms facing each other.",
    "diamond_pushup": "Hands together under your chest.",
    "archer_pushup": "Hands wide; lower toward one hand while the other arm stays straight. Alternate sides.",
    "negative_pullup": "Jump or step to the top, then lower yourself slowly over 3–5 seconds.",
    "bw_split_squat": "Back foot on a bench, no weights.",
    "smith_bench": "Set the safeties just above chest height.",
    "smith_squat": "Feet slightly in front of the bar.",
    "bw_lunge": "Step backward instead of forward.",
    "kb_press": "Wrist straight, bell resting on the forearm.",
    "db_floor_press": "Great when you have no bench.",
    "cable_lateral": "Do one side, then switch.",
    "kb_row": "One side at a time, other hand on a support.",
    "band_curl": "Stand on the band.",
    "band_lateral": "Stand on the band.",
    "band_good_morning": "Stand on the band, loop it behind your neck.",
}



# ---------- 2D solver ----------

def d2r(a):
    return a * math.pi / 180.0

def vdir(a):
    r = d2r(a)
    return (math.cos(r), math.sin(r))

def lerp(a, b, t):
    return a + (b - a) * t

def lerp_spec(sa, sb, t):
    assert sa["m"] == sb["m"] and sa["rel"] == sb["rel"] and sa["pl"] == sb["pl"], (sa, sb)
    out = dict(sa)
    out["a"] = lerp(sa["a"], sb["a"], t)
    out["b"] = lerp(sa["b"], sb["b"], t)
    out["fa"] = lerp(sa["fa"] if sa["fa"] is not None else 0.0, sb["fa"] if sb["fa"] is not None else 0.0, t)
    return out

def lerp_pose(a, b, t):
    out = dict(a)
    for k in ("x", "y", "torso", "head", "shrug", "ts", "hand_lat", "hand_shift", "leg_lat"):
        out[k] = lerp(a[k], b[k], t)
    for k in ("arm", "leg"):
        out[k] = lerp_spec(a[k], b[k], t)
    for k in ("arm2", "leg2"):
        sa, sb = a[k], b[k]
        if sa is None and sb is None:
            out[k] = None
        else:
            out[k] = lerp_spec(sa if sa is not None else a[k[:-1]], sb if sb is not None else b[k[:-1]], t)
    return out

def ik2(root, target, a, b, bend):
    dx, dy = target[0] - root[0], target[1] - root[1]
    dist = math.hypot(dx, dy)
    dist = max(abs(a - b) + 0.01, min(a + b - 0.01, dist))
    phi = math.atan2(dy, dx)
    alpha = math.acos(max(-1.0, min(1.0, (a * a + dist * dist - b * b) / (2 * a * dist))))
    mid = (root[0] + a * math.cos(phi + bend * alpha), root[1] + a * math.sin(phi + bend * alpha))
    end = (root[0] + dist * math.cos(phi), root[1] + dist * math.sin(phi))
    return mid, end

def mirror_spec(s, cx):
    m = dict(s)
    if s["m"] == "ang":
        m["a"], m["b"] = 180.0 - s["a"], 180.0 - s["b"]
    else:
        m["a"] = (2 * cx - s["a"]) if s["rel"] == "w" else -s["a"]
        m["bend"] = -s["bend"]
    m["fa"] = 180.0 - (s["fa"] or 0.0)
    return m

def solve_limb(spec, root, seg1, seg2, refs):
    if spec["m"] == "ang":
        da, db = vdir(spec["a"]), vdir(spec["b"])
        mid = (root[0] + seg1 * da[0], root[1] + seg1 * da[1])
        return mid, (mid[0] + seg2 * db[0], mid[1] + seg2 * db[1])
    base = refs[spec["rel"]]
    target = (base[0] + spec["a"], base[1] + spec["b"])
    if spec["m"] == "ik":
        return ik2(root, target, seg1, seg2, spec["bend"])
    return ((root[0] + target[0]) / 2.0, (root[1] + target[1]) / 2.0 - 0.8), target

def toe_of(ankle, fa, length):
    d = vdir(fa)
    return (ankle[0] + length * d[0], ankle[1] + length * d[1])

def solve3d(p, view, cx):
    """Returns the 18 body points in 3D: [x(forward), y(up), lat(sideways)]."""
    tl = L["torso"] * p["ts"]
    td = vdir(p["torso"])
    if p["root"] == "hip":
        hip = (p["x"], p["y"])
        neck = (hip[0] + tl * td[0], hip[1] + tl * td[1])
    else:
        neck = (p["x"], p["y"])
        hip = (neck[0] - tl * td[0], neck[1] - tl * td[1])
    hd = vdir(p["torso"] + p["head"])
    hr = L["neck"] + L["head"]
    head = (neck[0] + hd[0] * hr, neck[1] + hd[1] * hr)
    fd = vdir(p["torso"] + p["head"] - 90.0)

    if view == "s":
        sh = (neck[0], neck[1] + p["shrug"])
        refs = dict(w=(0.0, 0.0), sh=sh, hd=head, hip=hip)
        arms, legs = [], []
        for i, spec in enumerate((p["arm"], p["arm2"] if p["arm2"] is not None else p["arm"])):
            sign = -1.0 if i == 0 else 1.0
            so = sign * L["sh_off"]
            if spec["pl"] == "s":
                e, w = solve_limb(spec, sh, L["upper"], L["fore"], refs)
                E, W = [e[0], e[1], so], [w[0], w[1], so]
            else:
                e, w = solve_limb(spec, (0.0, 0.0), L["upper"], L["fore"], dict(sh=(0.0, 0.0), w=(0.0, 0.0)))
                if spec["pl"] == "f":
                    E = [sh[0], sh[1] + e[1], sign * (L["sh_off"] + e[0])]
                    W = [sh[0], sh[1] + w[1], sign * (L["sh_off"] + w[0])]
                else:
                    E = [sh[0] + e[1], sh[1], sign * (L["sh_off"] + e[0])]
                    W = [sh[0] + w[1], sh[1], sign * (L["sh_off"] + w[0])]
            E[2] += sign * p["hand_lat"] * 0.6 + p["hand_shift"] * 0.6
            W[2] += sign * p["hand_lat"] + p["hand_shift"]
            arms.append([[sh[0], sh[1], so], E, W])
        for i, spec in enumerate((p["leg"], p["leg2"] if p["leg2"] is not None else p["leg"])):
            sign = -1.0 if i == 0 else 1.0
            ho = sign * L["hip_off"]
            spread = sign * (L["hip_off"] + p["leg_lat"])
            k, a = solve_limb(spec, hip, L["thigh"], L["shin"], refs)
            t = toe_of(a, spec["fa"] or 0.0, L["foot"])
            legs.append([[hip[0], hip[1], ho], [k[0], k[1], spread], [a[0], a[1], spread], [t[0], t[1], spread]])
        core = [[head[0], head[1], 0.0], [neck[0], neck[1], 0.0], [hip[0], hip[1], 0.0]]
        nose = [head[0] + fd[0] * 3.6, head[1] + fd[1] * 3.6, 0.0]
    else:
        # Front-authored: 2D x is sideways. Index 0 = the figure's right side as seen (screen right at yaw 0).
        perp = vdir(p["torso"] - 90.0)
        rs = (neck[0] + perp[0] * L["sh_off"], neck[1] + perp[1] * L["sh_off"] + p["shrug"])
        ls = (neck[0] - perp[0] * L["sh_off"], neck[1] - perp[1] * L["sh_off"] + p["shrug"])
        rh = (hip[0] + perp[0] * L["hip_off"], hip[1] + perp[1] * L["hip_off"])
        lh = (hip[0] - perp[0] * L["hip_off"], hip[1] - perp[1] * L["hip_off"])
        mx = hip[0]
        arm_l = p["arm2"] if p["arm2"] is not None else mirror_spec(p["arm"], mx)
        leg_l = p["leg2"] if p["leg2"] is not None else mirror_spec(p["leg"], mx)

        def lift(pt):
            return [cx, pt[1], pt[0] - 50.0]
        arms, legs = [], []
        for spec, root in ((p["arm"], rs), (arm_l, ls)):
            refs = dict(w=(0.0, 0.0), sh=root, hd=head, hip=hip)
            e, w = solve_limb(spec, root, L["upper"], L["fore"], refs)
            arms.append([lift(root), lift(e), lift(w)])
        for spec, root in ((p["leg"], rh), (leg_l, lh)):
            refs = dict(w=(0.0, 0.0), sh=rs, hd=head, hip=hip)
            k, a = solve_limb(spec, root, L["thigh"], L["shin"], refs)
            t = toe_of(a, spec["fa"] or 0.0, L["ffoot"])
            legs.append([lift(root), lift(k), lift(a), lift(t)])
        core = [lift(head), lift(neck), lift(hip)]
        nose = [cx + 3.6, head[1], head[0] - 50.0]
    pts = core + arms[0] + arms[1] + legs[0] + legs[1] + [nose]
    return pts  # 18 points

# Point indices in a frame
HEAD, NECK, PELVIS = 0, 1, 2
ARM = [(3, 4, 5), (6, 7, 8)]          # shoulder, elbow, wrist
LEG = [(9, 10, 11, 12), (13, 14, 15, 16)]  # hip, knee, ankle, toe
NOSE = 17

def phase(t, period):
    u = (t % period) / period
    tri = u * 2 if u < 0.5 else 2 - u * 2
    x = max(0.0, min(1.0, (tri - 0.08) / 0.84))
    return 0.5 - 0.5 * math.cos(math.pi * x)

def pattern_center(pt):
    if pt["view"] == "f":
        return 50.0
    if pt.get("loop"):
        return 47.0
    xs = []
    for p in (pt["a"], pt["b"]):
        pts = solve3d(p, "s", 50.0)
        xs += [q[0] for q in pts]
    return round((min(xs) + max(xs)) / 2.0, 2)

def frames_for(pt):
    cx = pattern_center(pt)
    out = []
    if pt.get("loop"):
        for i in range(LOOP_FRAMES):
            t = i / (LOOP_FRAMES - 1)
            pts = solve3d(pt["gen"](t % 1.0), "s", cx)
            out.append([round(v, 2) for q in pts for v in q])
        return cx, out
    for i in range(NFRAMES):
        t = i / (NFRAMES - 1)
        pts = solve3d(lerp_pose(pt["a"], pt["b"], t), pt["view"], cx)
        out.append([round(v, 2) for q in pts for v in q])
    return cx, out

# ---------- props to 3D ----------

def props3d(props, view, cx):
    out = []
    for pr in props:
        if view == "s":
            def P3(x, y, z):
                return [x, y, z]
        else:
            def P3(x, y, z):  # authored x is sideways; z here is forward offset
                return [cx + z, y, x - 50.0]
        if pr["k"] == "line":
            pts = pr["pts"]
            if pr["w"] < 2.0:
                for z in (-6.0, 6.0):
                    for a, b in zip(pts, pts[1:]):
                        out.append(dict(k="seg", p=[P3(a[0], a[1], z), P3(b[0], b[1], z)], w=pr["w"]))
            else:
                hw = 7.0
                for a, b in zip(pts, pts[1:]):
                    out.append(dict(k="poly", p=[P3(a[0], a[1], -hw), P3(b[0], b[1], -hw), P3(b[0], b[1], hw), P3(a[0], a[1], hw)], w=pr["w"]))
        elif pr["k"] == "dot":
            (x, y), r = pr["pts"][0], pr["w"]
            out.append(dict(k="seg", p=[P3(x, y, -15.0), P3(x, y, 15.0)], w=r * 2))
        else:
            (x, y), (w, h) = pr["pts"]
            a, b = P3(x, y, -7.0), P3(x + w, y + h, 7.0)
            lo = [min(a[i], b[i]) for i in range(3)]
            hi = [max(a[i], b[i]) for i in range(3)]
            out.append(dict(k="box", p=[lo, hi], w=0))
    for o in out:
        o["p"] = [[round(v, 2) for v in q] for q in o["p"]]
    return out

# ---------- scene builder (ported 1:1 to Swift and JS) ----------

def project(P, yaw, cx):
    s, c = math.sin(yaw), math.cos(yaw)
    dx = P[0] - cx
    return (dx * s + P[2] * c + 50.0, P[1], dx * c - P[2] * s)

def hull(pts):
    pts = sorted(set(pts))
    if len(pts) <= 2:
        return pts
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]

def add3(a, b, k=1.0):
    return [a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k]

def mid3(*ps):
    n = float(len(ps))
    return [sum(p[i] for p in ps) / n for i in range(3)]

def norm3(v):
    m = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
    return [v[0] / m, v[1] / m, v[2] / m]

def scene(pat, ex, F, yaw):
    """Returns draw ops (depth-sorted). Op: dict(t=line|circle|poly, ...). Roles map to colors."""
    cx = pat["cx"]
    s = math.sin(yaw)
    pt = lambda i: [F[i * 3], F[i * 3 + 1], F[i * 3 + 2]]
    pr = lambda P: project(P, yaw, cx)
    props, items = [], []

    for prim in pat["pr"] + (ex.get("x") or []):
        q = [pr(P) for P in prim["p"]]
        if prim["k"] == "seg":
            props.append(dict(t="line", pts=[(a[0], a[1]) for a in q], w=prim["w"], role="prop", d=sum(a[2] for a in q) / len(q)))
        elif prim["k"] == "poly":
            props.append(dict(t="poly", pts=[(a[0], a[1]) for a in q], w=prim["w"], role="propFill", stroke="prop", d=sum(a[2] for a in q) / len(q)))
        else:
            lo, hi = prim["p"]
            corners = [[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
            qq = [pr(P) for P in corners]
            props.append(dict(t="poly", pts=hull([(round(a[0], 3), round(a[1], 3)) for a in qq]), w=0.8, role="propFill", stroke="prop",
                              d=sum(a[2] for a in qq) / 8.0))

    dT = (pr(pt(NECK))[2] + pr(pt(PELVIS))[2]) / 2.0

    def alpha(d):
        return 1.0 - 0.55 * max(0.0, min(1.0, (-2.0 - (d - dT)) / 10.0))

    def seg(i, j, w, role="ink"):
        a, b = pr(pt(i)), pr(pt(j))
        d = (a[2] + b[2]) / 2.0
        items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=w, role=role, a=alpha(d), d=d))

    seg(NECK, PELVIS, 4.4)
    seg(ARM[0][0], ARM[1][0], 3.4)
    seg(LEG[0][0], LEG[1][0], 3.4)
    for (S, E, W) in ARM:
        seg(S, E, 3.0); seg(E, W, 2.8)
    for (H, K, A, T) in LEG:
        seg(H, K, 3.4); seg(K, A, 3.0); seg(A, T, 2.4)
    hp = pr(pt(HEAD))
    items.append(dict(t="circle", c=(hp[0], hp[1]), rx=L["head"], ry=L["head"], role="ink", a=1.0, d=hp[2]))
    npnt = pr(pt(NOSE))
    if npnt[2] > hp[2] - 0.5:
        items.append(dict(t="circle", c=(npnt[0], npnt[1]), rx=1.1, ry=1.1, role="face", a=1.0, d=hp[2] + 0.01))

    # implements
    W = [pt(ARM[0][2]), pt(ARM[1][2])]
    S = [pt(ARM[0][0]), pt(ARM[1][0])]
    for im in ex.get("i", []):
        h = im["hands"]
        hands = [(W[0], 0), (W[1], 1)] if h == "both" else ([(W[0], 0)] if h == "near" else [(mid3(W[0], W[1]), 0)])
        t = im["t"]
        if t == "barbell":
            C = mid3(W[0], W[1]) if h != "near" else W[0]
            a, b = pr(add3(C, [0, 0, -22])), pr(add3(C, [0, 0, 22]))
            items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=1.4, role="steel", a=1.0, d=(a[2] + b[2]) / 2))
            for z in (-18.0, 18.0):
                p = pr(add3(C, [0, 0, z]))
                items.append(dict(t="circle", c=(p[0], p[1]), rx=max(1.1, 7.0 * abs(s)), ry=7.0, role="plate", a=1.0, d=p[2]))
        elif t == "dumbbell":
            for H, _ in hands:
                a, b = pr(add3(H, [0, 0, -3.5])), pr(add3(H, [0, 0, 3.5]))
                items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=1.3, role="steel", a=1.0, d=(a[2] + b[2]) / 2))
                for p in (a, b):
                    items.append(dict(t="circle", c=(p[0], p[1]), rx=max(1.0, 3.0 * abs(s)), ry=3.0, role="plate", a=1.0, d=p[2]))
        elif t == "kettlebell":
            for H, _ in hands:
                c3 = add3(H, [0, -4.6, 0])
                a, b = pr(H), pr(c3)
                items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=1.2, role="steel", a=1.0, d=b[2]))
                items.append(dict(t="circle", c=(b[0], b[1]), rx=3.6, ry=3.6, role="plate", a=1.0, d=b[2] + 0.01))
        elif t in ("cable", "band"):
            anc = im["anchor"]
            if anc == "hands":
                a, b = pr(W[0]), pr(W[1])
                items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=1.1, role="band", a=1.0, d=(a[2] + b[2]) / 2, dash=True))
                continue
            for H, i in hands:
                if anc == "foot":
                    A3 = pt(LEG[i][3])
                else:
                    sgn = 1.0 if S[i][2] >= 0 else -1.0
                    A3 = [anc[0], anc[1], H[2] if anc[2] is None else sgn * anc[2]]
                a, b = pr(H), pr(A3)
                d = (a[2] + b[2]) / 2
                if t == "cable":
                    items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=0.7, role="cable", a=1.0, d=d - 0.5))
                    items.append(dict(t="circle", c=(b[0], b[1]), rx=1.4, ry=1.4, role="steel", a=1.0, d=b[2]))
                    items.append(dict(t="circle", c=(a[0], a[1]), rx=1.5, ry=1.5, role="accent", a=1.0, d=a[2] + 0.02))
                else:
                    items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=1.1, role="band", a=1.0, d=d, dash=True))
        elif t == "wheel":
            H = hands[0][0]
            a = pr((H[0], H[1] - 2.0, H[2]))
            items.append(dict(t="circle", c=(a[0], a[1]), rx=3.4, ry=3.4, role="plate", a=1.0, d=a[2] + 0.02))
        elif t == "handle":
            for H, _ in hands:
                a = pr(H)
                items.append(dict(t="circle", c=(a[0], a[1]), rx=1.7, ry=1.7, role="accent", a=1.0, d=a[2] + 0.02))
        elif t == "pad":
            idx = {"ankle": (LEG[0][2], LEG[1][2]), "shoulder": (ARM[0][0], ARM[1][0])}[im["at"]]
            P0, P1 = pt(idx[0]), pt(idx[1])
            u = norm3([P0[i] - P1[i] for i in range(3)])
            a, b = pr(add3(P0, u, 3.0)), pr(add3(P1, u, -3.0))
            items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=4.4, role="pad", a=1.0, d=(a[2] + b[2]) / 2 + 0.5))
        elif t == "pedal":
            for (H, K, A, T) in LEG:
                a, b = pr(add3(pt(A), [-3.0, -2.2, 0])), pr(add3(pt(T), [1.5, -1.6, 0]))
                items.append(dict(t="line", pts=[(a[0], a[1]), (b[0], b[1])], w=2.2, role="steel", a=1.0, d=(a[2] + b[2]) / 2 - 0.3))
        elif t == "sled":
            A0, T0, A1, T1 = pt(LEG[0][2]), pt(LEG[0][3]), pt(LEG[1][2]), pt(LEG[1][3])
            m = mid3(A0, T0, A1, T1)
            u = norm3([T0[i] - A0[i] for i in range(3)])
            cs = [add3(add3(m, u, k1), [0, 0, k2]) for k1, k2 in ((-8, -9), (8, -9), (8, 9), (-8, 9))]
            q = [pr(P) for P in cs]
            items.append(dict(t="poly", pts=[(a[0], a[1]) for a in q], w=1.0, role="propFill", stroke="steel", a=1.0,
                              d=sum(a[2] for a in q) / 4 - 3))

    props.sort(key=lambda o: o["d"])
    items.sort(key=lambda o: o["d"])
    ground = [dict(t="line", pts=[(2.0, GROUND), (98.0, GROUND)], w=1.0, role="ground", d=-999)]
    return ground + props + items


# ---------- validation ----------

def check():
    issues = []
    for name, pt in P.items():
        poses = [("A", pt["a"]), ("B", pt["b"])]
        if pt.get("loop"):
            poses = [(f"t={i / 12:.2f}", pt["gen"](i / 12)) for i in range(12)]
        for label, p in poses:
            pts = solve3d(p, pt["view"], 50.0)
            for q in pts:
                if q[1] < GROUND - 1.0:
                    issues.append(f"{name} {label}: point below ground y={q[1]:.1f}")
                    break
            if pts[HEAD][1] + L["head"] > 104:
                issues.append(f"{name} {label}: head out of frame")
    missing = [k for k in EX if EX[k][0] not in P]
    no_cues = [k for k in P if k not in CUES]
    return issues, missing, no_cues


# ---------- export ----------

def build_json():
    pats = {}
    for name, pt in P.items():
        cx, frames = frames_for(pt)
        pats[name] = dict(view=pt["view"], T=pt["period"], cx=cx, f=frames, pr=props3d(pt["props"], pt["view"], cx),
                          loop=bool(pt.get("loop")))
    exs = {}
    for ex, v in EX.items():
        patn, imps = v[0], v[1]
        extra = v[2] if len(v) > 2 else None
        cx = pats[patn]["cx"]
        exs[ex] = dict(p=patn, i=[dict(t=i["t"], hands=i["hands"], anchor=i["anchor"], at=i["at"]) for i in imps],
                       x=(props3d(SMITH_RAILS, "s", cx) if extra == "smith" else []))
    return dict(v=1, ground=GROUND, head=L["head"], patterns=pats, exercises=exs, cues=CUES, tips=EX_TIPS)


# ---------- contact sheet ----------

def render_sheet(path, data, names, cell=140, yaws=(90, 0), ts=(0.0, 1.0)):
    from PIL import Image, ImageDraw
    cols = len(yaws) * len(ts)
    W, H = 150 + cell * cols, cell * len(names)
    img = Image.new("RGB", (W, H), (246, 245, 242))
    d = ImageDraw.Draw(img)
    bg = (246, 245, 242)
    colors = dict(ink=(32, 32, 38), accent=(232, 96, 40), plate=(232, 96, 40), steel=(90, 90, 96), prop=(160, 160, 165),
                  propFill=(214, 214, 216), cable=(150, 150, 155), band=(232, 96, 40), pad=(240, 150, 110), ground=(185, 185, 185),
                  face=(246, 245, 242))

    def mix(c, a):
        return tuple(int(bg[i] + (c[i] - bg[i]) * a) for i in range(3))
    for r, exid in enumerate(names):
        ex = data["exercises"][exid]
        pat = data["patterns"][ex["p"]]
        d.text((6, r * cell + 6), exid, fill=(30, 30, 30))
        col = 0
        for yaw in yaws:
            for t in ts:
                fi = t * (len(pat["f"]) - 1)
                F = pat["f"][int(round(fi))]
                ox, oy = 150 + col * cell, r * cell
                k = cell / 100.0
                X = lambda p: (ox + p[0] * k, oy + (100 - p[1]) * k)
                d.rectangle([ox, oy, ox + cell - 1, oy + cell - 1], outline=(220, 220, 220))
                for op in scene(pat, ex, F, math.radians(yaw)):
                    c = mix(colors[op["role"]], op.get("a", 1.0))
                    if op["t"] == "line":
                        d.line([X(p) for p in op["pts"]], fill=c, width=max(1, int(op["w"] * k)))
                    elif op["t"] == "circle":
                        cx_, cy_ = X(op["c"])
                        d.ellipse([cx_ - op["rx"] * k, cy_ - op["ry"] * k, cx_ + op["rx"] * k, cy_ + op["ry"] * k], fill=c)
                    else:
                        if len(op["pts"]) >= 3:
                            d.polygon([X(p) for p in op["pts"]], fill=c, outline=colors[op.get("stroke", "prop")])
                        else:
                            d.line([X(p) for p in op["pts"]], fill=colors[op.get("stroke", "prop")], width=max(1, int(op["w"] * k)))
                col += 1
    img.save(path)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", ".."))
    issues, missing, no_cues = check()
    for i in issues:
        print("WARN", i)
    if missing or no_cues:
        print("MISSING pattern:", missing, "no cues:", no_cues)
        sys.exit(1)
    data = build_json()
    with open(os.path.join(root, "Shared", "forms.json"), "w") as f:
        json.dump(data, f, separators=(",", ":"))
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1] if len(sys.argv) > sys.argv.index("--sheet") + 1 else here
        exs = list(EX.keys())
        for i in range(0, len(exs), 12):
            render_sheet(os.path.join(out, f"sheet{i // 12}.png"), data, exs[i:i + 12])
    print("patterns:", len(P), "exercises:", len(EX), "json bytes:", os.path.getsize(os.path.join(root, "Shared", "forms.json")))
