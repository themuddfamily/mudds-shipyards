import unittest
from tools.package.source_hash_provenance_v730 import validate_v730
class V730Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v730({"schema_version":730}),[])
 def test_schema(self):self.assertIn("schema_version must be 730",validate_v730({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v730({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v730({}),[])
if __name__=="__main__":unittest.main()
