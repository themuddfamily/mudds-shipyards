import unittest
from tools.package.source_hash_provenance_v562 import validate_v562
class V562Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v562({})))
 def test_schema(self):self.assertIn("schema_version must be 562",validate_v562({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v562({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v562({}),[])
if __name__=="__main__":unittest.main()
