import unittest
from tools.package.source_hash_provenance_v639 import validate_v639
class V639Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v639({"schema_version":639}),[])
 def test_schema(self):self.assertIn("schema_version must be 639",validate_v639({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v639({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v639({}),[])
if __name__=="__main__":unittest.main()
