import unittest
from tools.package.source_hash_provenance_v780 import validate_v780
class V780Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v780({"schema_version":780}),[])
 def test_schema(self):self.assertIn("schema_version must be 780",validate_v780({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v780({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v780({}),[])
if __name__=="__main__":unittest.main()
