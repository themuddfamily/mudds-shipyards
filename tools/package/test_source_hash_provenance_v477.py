import unittest
from tools.package.source_hash_provenance_v477 import validate_v477
class V477Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v477({})))
 def test_schema(self):self.assertIn("schema_version must be 477",validate_v477({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v477({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v477({}),[])
if __name__=="__main__":unittest.main()
