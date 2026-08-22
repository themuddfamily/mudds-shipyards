import unittest
from tools.package.source_hash_provenance_v595 import validate_v595
class V595Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v595({"schema_version":595}),[])
 def test_schema(self):self.assertIn("schema_version must be 595",validate_v595({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v595({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v595({}),[])
if __name__=="__main__":unittest.main()
