import unittest
from tools.package.source_hash_provenance_v632 import validate_v632
class V632Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v632({"schema_version":632}),[])
 def test_schema(self):self.assertIn("schema_version must be 632",validate_v632({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v632({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v632({}),[])
if __name__=="__main__":unittest.main()
