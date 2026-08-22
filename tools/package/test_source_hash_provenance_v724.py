import unittest
from tools.package.source_hash_provenance_v724 import validate_v724
class V724Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v724({"schema_version":724}),[])
 def test_schema(self):self.assertIn("schema_version must be 724",validate_v724({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v724({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v724({}),[])
if __name__=="__main__":unittest.main()
