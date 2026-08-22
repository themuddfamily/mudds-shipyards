import unittest
from tools.package.source_hash_provenance_v714 import validate_v714
class V714Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v714({"schema_version":714}),[])
 def test_schema(self):self.assertIn("schema_version must be 714",validate_v714({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v714({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v714({}),[])
if __name__=="__main__":unittest.main()
