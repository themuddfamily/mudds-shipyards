import unittest
from tools.package.source_hash_provenance_v638 import validate_v638
class V638Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v638({"schema_version":638}),[])
 def test_schema(self):self.assertIn("schema_version must be 638",validate_v638({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v638({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v638({}),[])
if __name__=="__main__":unittest.main()
