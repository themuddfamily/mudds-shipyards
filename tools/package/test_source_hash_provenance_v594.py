import unittest
from tools.package.source_hash_provenance_v594 import validate_v594
class V594Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v594({"schema_version":594}),[])
 def test_schema(self):self.assertIn("schema_version must be 594",validate_v594({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v594({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v594({}),[])
if __name__=="__main__":unittest.main()
