"""Regression checks for the chosen map family and complete construction art."""
import csv
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class TownAssetTests(unittest.TestCase):
    def test_reference_copies_keep_hashes_and_map_family(self):
        provenance = json.loads((ROOT / 'art_source/town/provenance.json').read_text(encoding='utf-8'))
        with (ROOT / 'data/source/resource_bindings.csv').open(encoding='utf-8', newline='') as f:
            bindings = {row['id']: row for row in csv.DictReader(f)}
        for asset_id, record in provenance['assets'].items():
            binding = bindings[asset_id]
            for name in [binding['source_path'], binding['runtime_path'].removeprefix('res://')]:
                self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), record['sha256'])
        for i in range(1, 7):
            self.assertEqual(provenance['assets'][f'town.bg{i}']['source'],
                             f'03_美术资源/02_透明切图/resources/tmp/map/common/bg{i}.png')

    def test_background_rectangles_tile_without_gaps(self):
        with (ROOT / 'data/source/town/town_backgrounds.csv').open(encoding='utf-8', newline='') as f:
            rows = list(csv.DictReader(f))
        self.assertEqual({(int(r['x']), int(r['y'])) for r in rows},
                         {(x * 2066, y * 2427) for x in range(3) for y in range(2)})

    def test_building_assets_keep_registered_source_hashes(self):
        records = json.loads((ROOT / 'art_source/operations/provenance.json').read_text(encoding='utf8'))['assets']
        with (ROOT / 'data/source/resource_bindings.csv').open(encoding='utf8') as source:
            bindings = {r['id']: r for r in csv.DictReader(source)}
        for aid, record in records.items():
            for field in ['source_path', 'runtime_path']:
                target = ROOT / bindings[aid][field].removeprefix('res://')
                self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(), record['sha256'], aid)


if __name__ == '__main__':
    unittest.main()
