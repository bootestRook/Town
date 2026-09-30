"""Source handoff must retain editable art and reject broken archives."""
from pathlib import Path
import contextlib
import io
import tempfile
import unittest
import zipfile

from tools import scaffold, source_archive


class SourceArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "project"
        self.root.mkdir()
        self.output = Path(self.temporary.name) / "project.zip"

    def tearDown(self):
        self.temporary.cleanup()

    def put(self, name, content=b"data"):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def entries(self):
        return {p.relative_to(self.root).as_posix() for p in source_archive.inventory(self.root)[0]}

    def populate_required(self):
        for name in ("project.godot", "README.md", "AI_AGENT_GUIDE.md", "LICENSE", "THIRD_PARTY.md"):
            self.put(name)

    def test_editable_art_import_settings_and_empty_directories_survive(self):
        wanted = {"art_source/actor.blend", "art_source/atlas.png", "assets/runtime/atlas.png.import"}
        for name in wanted:
            self.put(name)
        (self.root / "authoring/empty").mkdir(parents=True)
        self.assertEqual(wanted, self.entries())
        stage = Path(self.temporary.name) / "stage"
        source_archive.stage_project(self.root, stage)
        self.assertTrue((stage / "authoring/empty").is_dir())
        for name in wanted:
            self.assertEqual((self.root / name).read_bytes(), (stage / name).read_bytes())

    def test_cache_evidence_backups_and_old_manifest_are_excluded(self):
        for name in (".godot/imported/art.ctex", ".import/cache", "validation/record.png",
                     ".impeccable/review/screen.png", "tools/__pycache__/x.pyc", "art_source/actor.blend1",
                     "build/old.exe", "old.zip", "debug.log", source_archive.MANIFEST_NAME,
                     source_archive.LOCAL_SOURCE_DOCUMENT):
            self.put(name)
        self.put(".impeccable/design.json", b"{}")
        self.assertEqual({".impeccable/design.json"}, self.entries())

    def test_portable_links_leave_original_document_unchanged(self):
        text = "[source](SOURCE_REFERENCE.md) [log](../../validation/test.log) [rules](../../AGENTS.md)\n"
        source = self.put("docs/research/test.md", text.encode("utf-8"))
        stage = Path(self.temporary.name) / "stage"
        source_archive.stage_project(self.root, stage)
        portable = (stage / "docs/research/test.md").read_text(encoding="utf-8")
        self.assertIn("../../THIRD_PARTY.md", portable)
        self.assertNotIn("](../../validation/test.log)", portable)
        self.assertIn("[rules](../../AGENTS.md)", portable)
        self.assertEqual(text, source.read_text(encoding="utf-8"))

    def test_archive_roundtrip_and_staging_hash_gate(self):
        self.populate_required()
        self.put("art_source/actor.blend", b"editable")
        self.put(source_archive.MANIFEST_NAME, b"obsolete")
        scaffold.write_archive(self.root, self.output, "佣兵小镇")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertTrue(scaffold.check(self.output, self.root))
            self.put("art_source/actor.blend", b"changed")
            self.assertFalse(scaffold.check(self.output, self.root))
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(1, archive.namelist().count("佣兵小镇/scaffold-manifest.json"))

    def test_extra_or_duplicate_archive_entries_are_rejected(self):
        self.populate_required()
        scaffold.write_archive(self.root, self.output, "佣兵小镇")
        with zipfile.ZipFile(self.output, "a") as archive:
            archive.writestr("佣兵小镇/../outside.txt", b"unsafe")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertFalse(scaffold.check(self.output))


if __name__ == "__main__":
    unittest.main()
