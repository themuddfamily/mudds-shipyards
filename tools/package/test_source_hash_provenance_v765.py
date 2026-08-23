import unittest
from tools.package.source_hash_provenance_v765 import validate_v765
class V765Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v765({"schema_version":765}),[])
 def test_schema(self):self.assertIn("schema_version must be 765",validate_v765({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v765({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v765({}),[])
if __name__=="__main__":unittest.main()
