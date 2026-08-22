import unittest
from tools.package.source_hash_provenance_v653 import validate_v653
class V653Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v653({"schema_version":653}),[])
 def test_schema(self):self.assertIn("schema_version must be 653",validate_v653({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v653({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v653({}),[])
if __name__=="__main__":unittest.main()
