import unittest
from tools.package.source_hash_provenance_v710 import validate_v710
class V710Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v710({"schema_version":710}),[])
 def test_schema(self):self.assertIn("schema_version must be 710",validate_v710({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v710({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v710({}),[])
if __name__=="__main__":unittest.main()
