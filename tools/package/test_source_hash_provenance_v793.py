import unittest
from tools.package.source_hash_provenance_v793 import validate_v793
class V793Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v793({"schema_version":793}),[])
 def test_schema(self):self.assertIn("schema_version must be 793",validate_v793({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v793({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v793({}),[])
if __name__=="__main__":unittest.main()
