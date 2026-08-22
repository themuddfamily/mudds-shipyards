import unittest
from tools.package.source_hash_provenance_v726 import validate_v726
class V726Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v726({"schema_version":726}),[])
 def test_schema(self):self.assertIn("schema_version must be 726",validate_v726({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v726({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v726({}),[])
if __name__=="__main__":unittest.main()
