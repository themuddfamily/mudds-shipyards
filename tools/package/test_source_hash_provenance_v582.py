import unittest
from tools.package.source_hash_provenance_v582 import validate_v582
class V582Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v582({})))
 def test_schema(self):self.assertIn("schema_version must be 582",validate_v582({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v582({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v582({}),[])
if __name__=="__main__":unittest.main()
