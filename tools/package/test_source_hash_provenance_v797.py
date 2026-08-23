import unittest
from tools.package.source_hash_provenance_v797 import validate_v797
class V797Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v797({"schema_version":797}),[])
 def test_schema(self):self.assertIn("schema_version must be 797",validate_v797({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v797({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v797({}),[])
if __name__=="__main__":unittest.main()
