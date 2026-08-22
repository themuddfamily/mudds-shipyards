import unittest
from tools.package.source_hash_provenance_v655 import validate_v655
class V655Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v655({"schema_version":655}),[])
 def test_schema(self):self.assertIn("schema_version must be 655",validate_v655({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v655({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v655({}),[])
if __name__=="__main__":unittest.main()
