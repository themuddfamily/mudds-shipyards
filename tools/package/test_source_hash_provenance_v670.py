import unittest
from tools.package.source_hash_provenance_v670 import validate_v670
class V670Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v670({"schema_version":670}),[])
 def test_schema(self):self.assertIn("schema_version must be 670",validate_v670({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v670({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v670({}),[])
if __name__=="__main__":unittest.main()
