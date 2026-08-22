import unittest
from tools.package.source_hash_provenance_v606 import validate_v606
class V606Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v606({"schema_version":606}),[])
 def test_schema(self):self.assertIn("schema_version must be 606",validate_v606({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v606({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v606({}),[])
if __name__=="__main__":unittest.main()
