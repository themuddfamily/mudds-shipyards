import unittest
from tools.package.source_hash_provenance_v803 import validate_v803
class V803Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v803({"schema_version":803}),[])
 def test_schema(self):self.assertIn("schema_version must be 803",validate_v803({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v803({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v803({}),[])
if __name__=="__main__":unittest.main()
