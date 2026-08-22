import unittest
from tools.package.source_hash_provenance_v444 import validate_v444
class V444Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v444({})))
 def test_schema(self):self.assertIn("schema_version must be 444",validate_v444({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v444({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v444({}),[])
if __name__=="__main__":unittest.main()
