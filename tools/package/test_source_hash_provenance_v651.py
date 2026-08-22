import unittest
from tools.package.source_hash_provenance_v651 import validate_v651
class V651Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v651({"schema_version":651}),[])
 def test_schema(self):self.assertIn("schema_version must be 651",validate_v651({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v651({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v651({}),[])
if __name__=="__main__":unittest.main()
