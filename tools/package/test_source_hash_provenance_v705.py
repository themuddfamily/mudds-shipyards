import unittest
from tools.package.source_hash_provenance_v705 import validate_v705
class V705Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v705({"schema_version":705}),[])
 def test_schema(self):self.assertIn("schema_version must be 705",validate_v705({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v705({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v705({}),[])
if __name__=="__main__":unittest.main()
