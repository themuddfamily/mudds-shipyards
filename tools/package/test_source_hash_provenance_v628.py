import unittest
from tools.package.source_hash_provenance_v628 import validate_v628
class V628Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v628({"schema_version":628}),[])
 def test_schema(self):self.assertIn("schema_version must be 628",validate_v628({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v628({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v628({}),[])
if __name__=="__main__":unittest.main()
