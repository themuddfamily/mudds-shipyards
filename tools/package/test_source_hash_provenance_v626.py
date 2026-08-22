import unittest
from tools.package.source_hash_provenance_v626 import validate_v626
class V626Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v626({"schema_version":626}),[])
 def test_schema(self):self.assertIn("schema_version must be 626",validate_v626({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v626({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v626({}),[])
if __name__=="__main__":unittest.main()
