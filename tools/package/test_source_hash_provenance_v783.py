import unittest
from tools.package.source_hash_provenance_v783 import validate_v783
class V783Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v783({"schema_version":783}),[])
 def test_schema(self):self.assertIn("schema_version must be 783",validate_v783({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v783({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v783({}),[])
if __name__=="__main__":unittest.main()
