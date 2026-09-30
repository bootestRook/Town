"""Guard against clipped poses, frame bleeding and substituted health-bar artwork."""
import csv
import hashlib
import json
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


class ActorArtTests(unittest.TestCase):
    def test_every_pose_stays_inside_its_frame(self):
        with (ROOT / 'data/source/town/town_animations.csv').open(encoding='utf-8') as source:
            rows = list(csv.DictReader(source))
        with (ROOT / 'data/source/town/town_heroes.csv').open(encoding='utf-8') as source:
            heroes = list(csv.DictReader(source))
        with (ROOT / 'data/source/town/main_heroes.csv').open(encoding='utf-8') as source:
            recruits = list(csv.DictReader(source))
        self.assertEqual({r['source_appearance'] for r in heroes}, {r['appearance'] for r in recruits})
        self.assertEqual(sum(r['initially_owned'] == 'true' for r in heroes), 3)
        with (ROOT / 'data/source/town/town_monsters.csv').open(encoding='utf-8') as source:
            monsters = {r['visual'] for r in csv.DictReader(source)}
        with (ROOT / 'data/source/town/main_horn_levels.csv').open(encoding='utf-8') as source:
            monsters.update(r['visual'] for r in csv.DictReader(source))
        self.assertEqual(len(rows), sum(10 if r['job']=='2' else 12 for r in heroes) + len(monsters) * 8)
        self.assertTrue(monsters <= {r['actor'] for r in rows})
        for row in rows:
            with self.subTest(animation=row['id']):
                w, h = int(row['frame_width']), int(row['frame_height'])
                columns, lines = int(row['columns']), int(row['rows'])
                with Image.open(ROOT / f'assets/runtime/heroes/{row["id"]}.png') as image:
                    self.assertEqual(image.size, (w * columns, h * lines))
                    self.assertGreaterEqual(columns * lines, int(row['frames']))
                    self.assertLess(columns * (lines - 1), int(row['frames']))
                    self.assertGreaterEqual(int(row['frames']), round(float(row['seconds'])*30))
                    alpha = image.getchannel('A')
                    for i in range(int(row['frames'])):
                        x, y = i % columns * w, i // columns * h
                        bounds = alpha.crop((x, y, x + w, y + h)).getbbox()
                        if bounds is None:
                            # An authored death fade may end at zero alpha; living poses never may.
                            self.assertEqual(row['action'], 'death', (row['id'], i))
                            self.assertEqual(i, int(row['frames']) - 1, (row['id'], i))
                            continue
                        self.assertIsNotNone(bounds, (row['id'], i))
                        self.assertGreaterEqual(min(bounds[0], bounds[1], w - bounds[2], h - bounds[3]), 3, (row['id'], i, bounds))
                    self.assertGreater(int(row['origin_y']), 0)
                    self.assertLess(int(row['origin_y']), h)

    def test_health_art_is_exact_source_copy(self):
        records = json.loads((ROOT / 'art_source/heroes/ui_sources.json').read_text(encoding='utf-8'))
        sizes = {'health_track': (58, 9), 'monster_health_track': (58, 9), 'health_fill': (54, 5), 'level_badge': (19, 19), 'hero_shadow': (65, 13)}
        for name, size in sizes.items():
            path = ROOT / f'assets/runtime/heroes/ui/{name}.png'
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), records[name]['sha256'])
            with Image.open(path) as image:
                self.assertEqual(image.size, size)
