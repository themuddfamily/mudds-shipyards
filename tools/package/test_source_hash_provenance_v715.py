import unittest
from tools.package.source_hash_provenance_v715 import validate_v715
class V715Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v715({"schema_version":715}),[])
 def test_schema(self):self.assertIn("schema_version must be 715",validate_v715({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v715({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v715({}),[])
if __name__=="__main__":unittest.main()
