import unittest
from tools.package.source_hash_provenance_v646 import validate_v646
class V646Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v646({"schema_version":646}),[])
 def test_schema(self):self.assertIn("schema_version must be 646",validate_v646({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v646({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v646({}),[])
if __name__=="__main__":unittest.main()
