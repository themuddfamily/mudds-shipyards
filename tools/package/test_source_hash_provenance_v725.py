import unittest
from tools.package.source_hash_provenance_v725 import validate_v725
class V725Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v725({"schema_version":725}),[])
 def test_schema(self):self.assertIn("schema_version must be 725",validate_v725({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v725({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v725({}),[])
if __name__=="__main__":unittest.main()
