import unittest
from tools.package.source_hash_provenance_v613 import validate_v613
class V613Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v613({"schema_version":613}),[])
 def test_schema(self):self.assertIn("schema_version must be 613",validate_v613({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v613({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v613({}),[])
if __name__=="__main__":unittest.main()
