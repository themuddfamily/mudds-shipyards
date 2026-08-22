import unittest
from tools.package.source_hash_provenance_v708 import validate_v708
class V708Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v708({"schema_version":708}),[])
 def test_schema(self):self.assertIn("schema_version must be 708",validate_v708({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v708({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v708({}),[])
if __name__=="__main__":unittest.main()
