import unittest
from tools.package.source_hash_provenance_v753 import validate_v753
class V753Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v753({"schema_version":753}),[])
 def test_schema(self):self.assertIn("schema_version must be 753",validate_v753({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v753({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v753({}),[])
if __name__=="__main__":unittest.main()
