import unittest
from tools.package.source_hash_provenance_v792 import validate_v792
class V792Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v792({"schema_version":792}),[])
 def test_schema(self):self.assertIn("schema_version must be 792",validate_v792({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v792({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v792({}),[])
if __name__=="__main__":unittest.main()
