import unittest
from tools.package.source_hash_provenance_v622 import validate_v622
class V622Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v622({"schema_version":622}),[])
 def test_schema(self):self.assertIn("schema_version must be 622",validate_v622({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v622({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v622({}),[])
if __name__=="__main__":unittest.main()
