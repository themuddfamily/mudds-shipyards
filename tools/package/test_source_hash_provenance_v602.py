import unittest
from tools.package.source_hash_provenance_v602 import validate_v602
class V602Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v602({"schema_version":602}),[])
 def test_schema(self):self.assertIn("schema_version must be 602",validate_v602({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v602({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v602({}),[])
if __name__=="__main__":unittest.main()
