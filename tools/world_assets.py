"""Canonical, self-contained Evolution Obby scenery and gameplay geometry.

The same descriptors are embedded in the place and exported to WorldLayout.luau,
so opening the place in Studio never depends on server startup to show the map.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEMES = [
    ("VƯỜN KHỞI ĐẦU", (99, 185, 112), (55, 120, 76), "Grass"),
    ("KHU RỪNG NẤM", (151, 200, 106), (111, 68, 148), "Grass"),
    ("HANG PHA LÊ", (94, 169, 209), (91, 108, 192), "Slate"),
    ("ĐẦM LẦY ẾCH", (93, 173, 138), (53, 118, 130), "Grass"),
    ("BỜ BIỂN RÙA", (240, 210, 133), (75, 179, 206), "Sand"),
    ("ĐỒNG HOA THỎ", (154, 203, 144), (244, 160, 196), "Grass"),
    ("PHỐ MÈO", (157, 151, 217), (93, 88, 153), "Brick"),
    ("THUNG LŨNG CHÓ SĂN", (177, 165, 113), (101, 143, 94), "Grass"),
    ("RỪNG KHỈ", (70, 147, 105), (215, 165, 66), "Grass"),
    ("THẢO NGUYÊN BÁO", (228, 188, 97), (200, 122, 67), "Sand"),
    ("CAO NGUYÊN CHUỘT TÚI", (203, 140, 112), (142, 86, 103), "Rock"),
    ("NÚI TINH TINH", (135, 151, 173), (91, 109, 146), "Slate"),
    ("MÂY NGỰA CÁNH", (182, 204, 239), (148, 126, 218), "Snow"),
    ("ĐỈNH PHƯỢNG HOÀNG", (236, 156, 91), (186, 69, 68), "Basalt"),
]


def stage_position(stage: int) -> tuple[float, float, float]:
    return (stage * 26, 11, round(7 * math.sin(stage * math.pi / 5), 3))


def descriptors() -> list[dict]:
    records: list[dict] = []

    def add(name, size, position, color, **kwargs):
        record = dict(name=name, size=list(size), position=list(position), color=list(color), group="Scenery")
        record.update(kwargs)
        records.append(record)
        return record

    def text(name, position, title, subtitle="", color=(244, 246, 255), width=320, height=88):
        return add(name, (1, 1, 1), position, color, collide=False, transparency=1,
                   billboard=dict(title=title, subtitle=subtitle, width=width, height=height))

    # A tangible, neutral spawn and a large landing platform exist before any script runs.
    add("LobbyGround", (82, 3, 112), (-16, 8.5, -16), (47, 66, 94), material="Slate")
    add("LobbyFloor", (80, 0.35, 110), (-16, 10.2, -16), (68, 94, 116), material="SmoothPlastic")
    add("StartSpawn", (16, 1, 16), (0, 11, 0), (102, 229, 177), group="Gameplay",
        class_name="SpawnLocation", kind="spawn", material="Neon", rotation=(0, -90, 0))
    # Decorative rails stop accidental falls around the lobby, leaving the course entrance open.
    for name, size, position in [
        ("LobbyBackRail", (1.2, 4, 112), (-57, 12, -16)),
        ("LobbyNorthRail", (82, 4, 1.2), (-16, 12, -72)),
        ("LobbySouthRail", (82, 4, 1.2), (-16, 12, 40)),
    ]:
        add(name, size, position, (96, 150, 176), transparency=.15, material="Glass")
    text("WelcomeSign", (-14, 22, 11), "EVOLUTION OBBY", "140 checkpoint • 15 loài • 5 đột biến", (132, 240, 205), 450, 110)
    text("Instructions", (-28, 15, 18), "ĐI THEO MŨI TÊN →", "WASD di chuyển · Space nhảy · E tại trạm đột biến", width=400, height=80)
    text("GallerySign", (-27, 19, -47), "SÁCH TIẾN HÓA", "Cứ 10 checkpoint: mở khóa hình dạng mới", (243, 210, 131), 380)
    text("SaveHint", (-43, 13, 2), "ĐƯỜNG MÀU XANH = CHECKPOINT", "Rơi hoặc chạm dung nham: hồi sinh tại mốc gần nhất", width=370, height=80)
    species = ("Ốc Sên", "Sâu Bướm", "Chuột", "Ếch", "Rùa", "Thỏ", "Mèo", "Chó Săn", "Khỉ", "Báo Gấm", "Chuột Túi", "Tinh Tinh", "Ngựa Cánh", "Phượng Hoàng", "Rồng Trắng")
    for index, species_name in enumerate(species):
        gx, gz = -44 + index % 5 * 12, -28 - index // 5 * 16
        add(f"GalleryPodium{index + 1:02d}", (10, 1, 10), (gx, 10.8, gz), (86, 103, 137), material="Slate")
        add(f"GalleryRim{index + 1:02d}", (10.2, .12, 10.2), (gx, 11.35, gz), (134, 209, 227), material="Neon", collide=False)
        text(f"GalleryLabel{index + 1:02d}", (gx, 16.8, gz), f"{index + 1:02d} · {species_name}", f"{index * 10} checkpoint", (231, 239, 255), width=145, height=54)

    # Fourteen compact themed islands. The lower ledge catches modest missed jumps;
    # it is still necessary to visit the numbered checkpoints in order.
    for zone, (title, grass, accent, material) in enumerate(THEMES):
        x = zone * 260 + 130
        add(f"Island{zone:02d}", (258, 5, 78), (x, 5.5, 0), grass, material=material)
        add(f"IslandRock{zone:02d}", (246, 10, 68), (x, -1.5, 0), (67, 76, 95), material="Rock")
        text(f"ZoneSign{zone:02d}", (zone * 260 + 28, 20, -22), f"{zone + 1:02d} · {title}",
             f"Checkpoint {zone * 10 + 1}–{(zone + 1) * 10}", accent, width=370)
        for edge in range(5):
            tx = zone * 260 + 30 + edge * 49
            # Deterministic scenery never obstructs the playable corridor.
            if zone in (2, 10, 11, 13):
                add(f"Crystal{zone}_{edge}", (3 + edge % 2, 11 + edge % 3 * 3, 3), (tx, 14, -28), accent,
                    material="Neon" if zone in (2, 13) else "Slate", rotation=(0, 20 + edge * 13, 12))
                add(f"Rock{zone}_{edge}", (10, 7, 7), (tx + 11, 10, 27), accent, shape="Ball", material="Rock")
            elif zone == 12:
                add(f"Cloud{zone}_{edge}", (22, 6, 12), (tx, 14, -27), (235, 240, 255), shape="Ball", collide=False)
                add(f"CloudSmall{zone}_{edge}", (13, 7, 12), (tx + 9, 15, -27), (242, 246, 255), shape="Ball", collide=False)
            elif zone == 4:
                add(f"PalmTrunk{zone}_{edge}", (2, 12, 2), (tx, 14, -27), (147, 107, 67), material="Wood")
                for leaf in range(3):
                    add(f"PalmLeaf{zone}_{edge}_{leaf}", (14, .6, 3), (tx, 20, -27), (58, 154, 93),
                        rotation=(0, leaf * 60, 12), collide=False)
            else:
                add(f"TreeTrunk{zone}_{edge}", (2.5, 10, 2.5), (tx, 13, -28), (124, 85, 60), material="Wood")
                add(f"TreeCrown{zone}_{edge}", (11, 12, 11), (tx, 21, -28), accent, shape="Ball", collide=False)
                add(f"FlowerStem{zone}_{edge}", (.6, 3, .6), (tx + 7, 9.5, 28), (62, 130, 81), collide=False)
                add(f"Flower{zone}_{edge}", (4, 1, 4), (tx + 7, 11, 28), accent, shape="Ball", collide=False)

    for stage in range(141):
        x, y, z = stage_position(stage)
        if stage:
            add(f"Checkpoint{stage:03d}", (14, 1, 14), (x, y, z), (85, 219, 164),
                material="SmoothPlastic", group="Gameplay", kind="checkpoint", stage=stage)
            add(f"CheckpointGlow{stage:03d}", (12, .1, 12), (x, y + .55, z), (132, 250, 196),
                material="Neon", collide=False)
            text(f"CheckpointLabel{stage:03d}", (x, y + 6, z - 8), str(stage),
                 "TIẾN HÓA!" if stage % 10 == 0 else "CHECKPOINT", (167, 255, 209), width=120, height=58)
            # Recovery steps let the slow first form return from the island ledge.
            add(f"RecoveryStep{stage:03d}", (8, 1, 3), (x, 9, z + 8), (86, 149, 121))
        if stage < 140:
            nx, _, nz = stage_position(stage + 1)
            for step in (1, 2):
                px = x + (nx - x) * step / 3
                pz = z + (nz - z) * step / 3
                # Max horizontal gap is <1.3 studs with the minimum 8-stud width.
                width = 9 if stage < 30 else 8
                add(f"Jump{stage:03d}_{step}", (width, 1, 10), (round(px, 3), y, round(pz, 3)),
                    (109, 151, 225), group="Course", material="SmoothPlastic")
                for chevron, yaw in enumerate((-35, 35)):
                    add(f"Direction{stage:03d}_{step}_{chevron}", (2, .12, .45), (round(px, 3), y + .6, round(pz + (-.5 if chevron == 0 else .5), 3)),
                        (236, 243, 255), collide=False, rotation=(0, yaw, 0))
            cx, cz = x + (nx - x) / 3, z + (nz - z) / 3
            add(f"Coin{stage + 1:03d}", (1.5, 1.5, 1.5), (round(cx, 3), y + 2.5, round(cz, 3)),
                (255, 212, 75), group="Gameplay", kind="coin", id=stage + 1, value=25,
                collide=False, shape="Ball", material="Neon")
            # Red obstacles occupy only the centre strip; every form can go around.
            if stage >= 30 and stage % 3 == 0:
                add(f"Lava{stage:03d}", (1.25, .25, 4), (round(x + 17.33, 3), y + .7, round(z + (nz - z) * 2 / 3, 3)),
                    (251, 79, 40), material="Neon", group="Gameplay", kind="hazard", collide=False)
            if stage > 10 and stage % 5 == 2:
                add(f"Hurdle{stage:03d}", (1, 1.25, 4), (round(x + 17.33, 3), y + 1.125, round(z + (nz - z) * 2 / 3, 3)),
                    (237, 185, 82), material="Wood")
        if stage % 10 == 0:
            # The station has a generous platform attached to the checkpoint.
            add(f"StationDeck{stage:03d}", (14, 1, 18), (x, y, z + 12), (98, 92, 157), material="SmoothPlastic")
            add(f"MutationPad{stage:03d}", (6, .6, 6), (x, y + .8, z + 13), (192, 125, 249), group="Gameplay",
                kind="station", material="Neon", prompt={"action": "Đột biến · 500 Coins", "object": "Trạm đột biến", "distance": 12})
            add(f"StationRing{stage:03d}", (8, .3, 8), (x, y + .6, z + 13), (116, 71, 178), material="SmoothPlastic")
            text(f"StationSign{stage:03d}", (x, y + 7, z + 15), "ĐỘT BIẾN", "Nhấn E · 500 Coins", (215, 175, 255), width=180, height=70)
            if stage < 140:
                text(f"EvolutionSign{stage:03d}", (x + 5, y + 10, z + 23),
                     "HÌNH DẠNG MỚI" if stage else "BẮT ĐẦU BẰNG ỐC SÊN", "Mở Sách Tiến Hóa để đổi loài", (255, 223, 147), width=270, height=70)

    # Optional mastery routes are clearly labelled and never block progression.
    # Jump sizes are appropriate for the form already unlocked at the zone entry.
    for index, stage in enumerate((30, 60, 90, 120)):
        x, y, z = stage_position(stage)
        accent = ((147, 217, 147), (219, 158, 245), (254, 199, 111), (163, 215, 251))[index]
        text(f"BonusSign{stage}", (x + 38, 20, 29), "THỬ THÁCH PHỤ", "Lối dài bên phải · không bắt buộc", accent, width=270, height=75)
        for step in range(5):
            add(f"BonusStep{stage}_{step}", (7, 1, 7), (x + step * 10, y + step * 1.3, 28), accent,
                group="Bonus", material="SmoothPlastic")
        add(f"BonusReturn{stage}", (25, 1, 9), (x + 40, y + 5.2, 20), accent, group="Bonus")
        # Ladder-like shallow staircase returns to the main course without a long fall.
        for step in range(4):
            add(f"BonusDown{stage}_{step}", (6, 1, 6), (x + 40 + step * 4, y + 5.2 - step * 1.3, 12 - step * 3), accent, group="Bonus")

    # Ability trials are side routes: the central checkpoints always stay open.
    def trial_entry(stage, length, title, hint, color):
        tx, ty, tz = stage_position(stage)
        add(f"TrialEntry{stage}", (14, 1, 21), (tx, ty, tz + 27), color, group="Trials")
        add(f"TrialFloor{stage}", (length, 1, 20), (tx + length / 2 - 5, ty, 46), (63, 79, 108), group="Trials", material="Slate")
        text(f"TrialTitle{stage}", (tx + 16, ty + 9, 37), title, hint, color, width=330, height=86)
        return tx, ty

    def trial_exit(stage, position):
        add(f"TrialReturn{stage}", (8, .35, 8), position, (111, 236, 187), group="Gameplay", kind="return", material="Neon",
            prompt={"action": "Về checkpoint", "object": "Kết thúc thử thách phụ", "distance": 10})
        text(f"TrialReturnSign{stage}", (position[0], position[1] + 6, position[2]), "LỐI RA", "Nhấn E: về checkpoint", (151, 255, 211), width=180, height=65)

    # Turtle's low body and Tiny mutation can fit beneath the low ceiling;
    # turtle's shell also shields the laser beams.
    tx, ty = trial_entry(40, 58, "ĐƯỜNG HẦM LASER", "Thử thách phụ · Rùa miễn nhiễm laser", (226, 143, 224))
    for side in (-1, 1):
        add(f"LaserTunnelWall{side}", (38, 4.5, 1), (tx + 24, ty + 2.75, 46 + side * 7), (83, 100, 134), group="Trials")
    add("LaserTunnelRoof", (38, .5, 15), (tx + 24, ty + 5.15, 46), (138, 151, 178), group="Trials", transparency=.28)
    for beam in range(4):
        add(f"LowLaser{beam}", (.45, .45, 13), (tx + 11 + beam * 8, ty + 1.8, 46), (255, 60, 123), group="Gameplay",
            kind="hazard", immune_form=5, material="Neon", collide=False)
    trial_exit(40, (tx + 48, ty + .7, 46))

    # The lava wall visibly travels along a dedicated speed track. It cannot
    # cross the numbered course; waiting and movement use elapsed seconds.
    tx, ty = trial_entry(90, 116, "CHẠY ĐUA DUNG NHAM", "Thử thách phụ · Báo Gấm chạy nhanh hơn bức tường", (255, 179, 95))
    for side in (-1, 1):
        add(f"RaceRail{side}", (116, 1, 1), (tx + 53, ty + 1.2, 46 + side * 10), (230, 137, 58), group="Trials")
    add("MovingLavaWall", (2, 8, 18), (tx + 7, ty + 4.5, 46), (250, 85, 38), group="Gameplay", kind="hazard", immune_form=14,
        material="Neon", collide=False, motion={"axis": "X", "distance": 92, "speed": 24, "pause": 6})
    trial_exit(90, (tx + 104, ty + .7, 46))

    # Wind really pushes players in this volume; Gorilla is heavy enough to
    # stand firm. Visible ribbons and a broad platform make the danger clear.
    tx, ty = trial_entry(110, 70, "HẺM NÚI GIÓ", "Thử thách phụ · Tinh Tinh đứng vững trước gió", (151, 218, 252))
    add("WindVolume", (45, 15, 20), (tx + 28, ty + 7, 46), (117, 196, 248), group="Gameplay", kind="wind",
        collide=False, transparency=1, immune_form=12, wind={"acceleration": 42, "max_speed": 22})
    for ribbon in range(5):
        add(f"WindRibbon{ribbon}", (35, .17, .35), (tx + 28, ty + 2 + ribbon * 1.1, 42 + ribbon * 1.4), (171, 231, 255),
            group="Trials", material="Neon", transparency=.35, collide=False, rotation=(0, -8, 0))
    trial_exit(110, (tx + 57, ty + .7, 46))

    # Phoenix's existing fire immunity has a visible firewalk to demonstrate it.
    tx, ty = trial_entry(130, 65, "CON ĐƯỜNG LỬA", "Thử thách phụ · Phượng Hoàng miễn nhiễm dung nham", (255, 154, 89))
    add("PhoenixFirewalk", (38, .2, 16), (tx + 26, ty + .7, 46), (255, 79, 29), group="Gameplay", kind="hazard",
        immune_form=14, material="Neon", collide=False)
    for flame in range(6):
        add(f"FirewalkFlame{flame}", (2, 3.5, 2), (tx + 9 + flame * 6, ty + 2.5, 39), (255, 174, 38),
            group="Trials", shape="Ball", material="Neon", collide=False)
    trial_exit(130, (tx + 52, ty + .7, 46))

    x, y, z = stage_position(140)
    add("FinaleIsland", (62, 4, 90), (x + 18, 8, 0), (205, 222, 239), material="Marble")
    add("FinalePlatform", (45, 1, 36), (x + 25, y, z), (218, 229, 246), material="Marble")
    for side in (-1, 1):
        add(f"DragonGatePillar{side}", (4, 26, 4), (x + 23, y + 13, side * 16), (222, 236, 255), material="Marble")
        add(f"DragonGateCrystal{side}", (5, 7, 5), (x + 23, y + 29, side * 16), (153, 226, 255), material="Neon", rotation=(0, 0, 20))
    add("DragonGateTop", (4, 3, 36), (x + 23, y + 26, 0), (173, 199, 236), material="Marble")
    text("VictorySign", (x + 28, y + 20, 0), "RỒNG TRẮNG ĐÃ THỨC TỈNH!", "Bạn đã hoàn thành 140 checkpoint", (231, 248, 255), width=470, height=110)
    add("Void", (3900, 1, 250), (1800, -30, 0), (255, 70, 60), transparency=1,
        group="Gameplay", kind="void", collide=False)
    return records


def _lua(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (list, tuple)):
        return "{" + ",".join(_lua(v) for v in value) + "}"
    return "{" + ",".join(f"{key}={_lua(v)}" for key, v in value.items()) + "}"


def write_layout(output: Path | None = None):
    output = output or ROOT / "src/shared/WorldLayout.luau"
    output.write_text("-- Generated by tools/world_assets.py. Edit the canonical descriptors, then rebuild.\nreturn {\n" +
                      "\n".join(" " + _lua(record) + "," for record in descriptors()) + "\n}\n", encoding="utf-8")
    return output


if __name__ == "__main__":
    print(write_layout())
