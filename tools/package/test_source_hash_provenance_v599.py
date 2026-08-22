import unittest
from tools.package.source_hash_provenance_v599 import validate_v599
class V599Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v599({"schema_version":599}),[])
 def test_schema(self):self.assertIn("schema_version must be 599",validate_v599({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v599({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v599({}),[])
if __name__=="__main__":unittest.main()
