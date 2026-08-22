import unittest
from tools.package.source_hash_provenance_v644 import validate_v644
class V644Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v644({"schema_version":644}),[])
 def test_schema(self):self.assertIn("schema_version must be 644",validate_v644({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v644({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v644({}),[])
if __name__=="__main__":unittest.main()
