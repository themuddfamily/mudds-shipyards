import unittest
from tools.package.source_hash_provenance_v702 import validate_v702
class V702Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v702({"schema_version":702}),[])
 def test_schema(self):self.assertIn("schema_version must be 702",validate_v702({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v702({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v702({}),[])
if __name__=="__main__":unittest.main()
