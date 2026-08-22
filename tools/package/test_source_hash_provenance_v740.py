import unittest
from tools.package.source_hash_provenance_v740 import validate_v740
class V740Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v740({"schema_version":740}),[])
 def test_schema(self):self.assertIn("schema_version must be 740",validate_v740({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v740({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v740({}),[])
if __name__=="__main__":unittest.main()
