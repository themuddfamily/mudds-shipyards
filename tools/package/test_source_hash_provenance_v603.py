import unittest
from tools.package.source_hash_provenance_v603 import validate_v603
class V603Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v603({"schema_version":603}),[])
 def test_schema(self):self.assertIn("schema_version must be 603",validate_v603({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v603({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v603({}),[])
if __name__=="__main__":unittest.main()
