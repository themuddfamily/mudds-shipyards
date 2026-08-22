import unittest
from tools.package.source_hash_provenance_v520 import validate_v520
class V520Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v520({})))
 def test_schema(self):self.assertIn("schema_version must be 520",validate_v520({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v520({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v520({}),[])
if __name__=="__main__":unittest.main()
