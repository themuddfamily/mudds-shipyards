import unittest
from tools.package.source_hash_provenance_v609 import validate_v609
class V609Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v609({"schema_version":609}),[])
 def test_schema(self):self.assertIn("schema_version must be 609",validate_v609({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v609({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v609({}),[])
if __name__=="__main__":unittest.main()
