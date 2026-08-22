import unittest
from tools.package.source_hash_provenance_v650 import validate_v650
class V650Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v650({"schema_version":650}),[])
 def test_schema(self):self.assertIn("schema_version must be 650",validate_v650({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v650({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v650({}),[])
if __name__=="__main__":unittest.main()
