import unittest
from tools.package.source_hash_provenance_v617 import validate_v617
class V617Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v617({"schema_version":617}),[])
 def test_schema(self):self.assertIn("schema_version must be 617",validate_v617({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v617({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v617({}),[])
if __name__=="__main__":unittest.main()
