import unittest
from tools.package.source_hash_provenance_v681 import validate_v681
class V681Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v681({"schema_version":681}),[])
 def test_schema(self):self.assertIn("schema_version must be 681",validate_v681({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v681({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v681({}),[])
if __name__=="__main__":unittest.main()
