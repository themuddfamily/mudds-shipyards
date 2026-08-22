import unittest
from tools.package.source_hash_provenance_v660 import validate_v660
class V660Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v660({"schema_version":660}),[])
 def test_schema(self):self.assertIn("schema_version must be 660",validate_v660({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v660({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v660({}),[])
if __name__=="__main__":unittest.main()
