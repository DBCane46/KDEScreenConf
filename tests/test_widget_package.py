import importlib.util
import json
import unittest
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('widget_package', ROOT / 'scripts/package-widget.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class WidgetPackageTest(unittest.TestCase):
    def test_complete_reproducible_qml_package(self):
        output = module.package()
        first = output.read_bytes()
        self.assertEqual(first, module.package().read_bytes())
        with ZipFile(output) as archive:
            names = archive.namelist()
            for name in ['metadata.json', 'LICENSE', 'contents/ui/main.qml', 'contents/ui/BackendNotice.qml', 'contents/images/kdescreenconf.svg']:
                self.assertIn(name, names)
            self.assertFalse(any(name.startswith(('bin/', 'src/', '/')) or '..' in Path(name).parts for name in names))
            self.assertEqual(json.loads(archive.read('metadata.json'))['KPackageStructure'], 'Plasma/Applet')
