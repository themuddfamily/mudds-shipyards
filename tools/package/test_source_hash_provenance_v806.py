import unittest
from tools.package.source_hash_provenance_v806 import validate_v806
class V806Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v806({"schema_version":806}),[])
 def test_schema(self):self.assertIn("schema_version must be 806",validate_v806({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v806({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v806({}),[])
if __name__=="__main__":unittest.main()
