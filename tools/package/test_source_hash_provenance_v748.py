import unittest
from tools.package.source_hash_provenance_v748 import validate_v748
class V748Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v748({"schema_version":748}),[])
 def test_schema(self):self.assertIn("schema_version must be 748",validate_v748({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v748({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v748({}),[])
if __name__=="__main__":unittest.main()
