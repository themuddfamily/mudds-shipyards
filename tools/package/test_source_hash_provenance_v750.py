import unittest
from tools.package.source_hash_provenance_v750 import validate_v750
class V750Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v750({"schema_version":750}),[])
 def test_schema(self):self.assertIn("schema_version must be 750",validate_v750({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v750({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v750({}),[])
if __name__=="__main__":unittest.main()
