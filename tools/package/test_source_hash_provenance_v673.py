import unittest
from tools.package.source_hash_provenance_v673 import validate_v673
class V673Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v673({"schema_version":673}),[])
 def test_schema(self):self.assertIn("schema_version must be 673",validate_v673({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v673({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v673({}),[])
if __name__=="__main__":unittest.main()
