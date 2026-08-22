import unittest
from tools.package.source_hash_provenance_v443 import validate_v443
class V443Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v443({})))
 def test_schema(self):self.assertIn("schema_version must be 443",validate_v443({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v443({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v443({}),[])
if __name__=="__main__":unittest.main()
