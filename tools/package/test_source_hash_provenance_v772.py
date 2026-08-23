import unittest
from tools.package.source_hash_provenance_v772 import validate_v772
class V772Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v772({"schema_version":772}),[])
 def test_schema(self):self.assertIn("schema_version must be 772",validate_v772({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v772({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v772({}),[])
if __name__=="__main__":unittest.main()
