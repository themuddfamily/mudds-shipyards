import unittest
from tools.package.source_hash_provenance_v640 import validate_v640
class V640Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v640({"schema_version":640}),[])
 def test_schema(self):self.assertIn("schema_version must be 640",validate_v640({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v640({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v640({}),[])
if __name__=="__main__":unittest.main()
