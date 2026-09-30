import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import delivery_check


class DeliveryBoundaries(unittest.TestCase):
    def check_fixture(self, source):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / source
            target.parent.mkdir(parents=True)
            target.write_text('extends RefCounted\n', encoding='utf-8', newline='\n')
            output = io.StringIO()
            with patch.object(delivery_check, 'PROJECT_ROOT', root), patch.object(delivery_check, 'REQUIRED', ()), contextlib.redirect_stdout(output):
                status = delivery_check.main()
            return status, output.getvalue()

    def test_game_rules_belong_in_feature(self):
        status, output = self.check_fixture('src/features/town/domain/town_combat.gd')
        self.assertEqual(status, 0, output)

    def test_game_rules_still_rejected_in_core(self):
        for layer in ['foundation', 'runtime']:
            with self.subTest(layer=layer):
                status, output = self.check_fixture(f'src/{layer}/monster_rules.gd')
                self.assertEqual(status, 1)
                self.assertIn('genre-specific core path found', output)
