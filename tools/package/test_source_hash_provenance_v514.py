import unittest
from tools.package.source_hash_provenance_v514 import validate_v514
class V514Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v514({})))
 def test_schema(self):self.assertIn("schema_version must be 514",validate_v514({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v514({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v514({}),[])
if __name__=="__main__":unittest.main()
