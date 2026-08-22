import unittest
from tools.package.source_hash_provenance_v500 import validate_v500
class V500Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v500({})))
 def test_schema(self):self.assertIn("schema_version must be 500",validate_v500({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v500({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v500({}),[])
if __name__=="__main__":unittest.main()
