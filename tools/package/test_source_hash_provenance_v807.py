import unittest
from tools.package.source_hash_provenance_v807 import validate_v807
class V807Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v807({"schema_version":807}),[])
 def test_schema(self):self.assertIn("schema_version must be 807",validate_v807({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v807({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v807({}),[])
if __name__=="__main__":unittest.main()
