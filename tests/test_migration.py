import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("migration", Path(__file__).parents[1]/"scripts/migrate_profiles.py")
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)

class Migration(unittest.TestCase):
    def test_preserves_original_and_existing_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/"kadr").mkdir()
            raw=json.dumps({"version":1,"automatic":False,"profiles":{"example":{"name":"Mobile","layouts":{"monitor":"custom"},"custom":{"monitor":[[0,0,1,1]]}}}}).encode()
            (root/"kadr/profiles.json").write_bytes(raw)
            self.assertTrue(migration.migrate(root))
            self.assertEqual((root/"kdescreenconf/profiles.json").read_bytes(),raw)
            self.assertEqual((root/"kadr/profiles.json").read_bytes(),raw)
            (root/"kdescreenconf/profiles.json").write_text("existing")
            self.assertFalse(migration.migrate(root))
            self.assertEqual((root/"kdescreenconf/profiles.json").read_text(),"existing")
    def test_invalid_source_is_not_migrated(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/"kadr").mkdir();(root/"kadr/profiles.json").write_text('{"version":99}')
            with self.assertRaises(ValueError):migration.migrate(root)
            self.assertFalse((root/"kdescreenconf/profiles.json").exists())

if __name__ == "__main__":unittest.main()
