import unittest
from tools.package.source_hash_provenance_v744 import validate_v744
class V744Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v744({"schema_version":744}),[])
 def test_schema(self):self.assertIn("schema_version must be 744",validate_v744({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v744({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v744({}),[])
if __name__=="__main__":unittest.main()
