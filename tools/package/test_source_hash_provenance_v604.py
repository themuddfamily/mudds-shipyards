import unittest
from tools.package.source_hash_provenance_v604 import validate_v604
class V604Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v604({"schema_version":604}),[])
 def test_schema(self):self.assertIn("schema_version must be 604",validate_v604({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v604({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v604({}),[])
if __name__=="__main__":unittest.main()
