import unittest
from tools.package.source_hash_provenance_v775 import validate_v775
class V775Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v775({"schema_version":775}),[])
 def test_schema(self):self.assertIn("schema_version must be 775",validate_v775({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v775({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v775({}),[])
if __name__=="__main__":unittest.main()
