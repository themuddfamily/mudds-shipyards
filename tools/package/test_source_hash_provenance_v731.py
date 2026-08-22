import unittest
from tools.package.source_hash_provenance_v731 import validate_v731
class V731Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v731({"schema_version":731}),[])
 def test_schema(self):self.assertIn("schema_version must be 731",validate_v731({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v731({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v731({}),[])
if __name__=="__main__":unittest.main()
