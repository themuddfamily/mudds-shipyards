import unittest
from tools.package.source_hash_provenance_v438 import validate_v438
class V438Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v438({})))
 def test_schema(self):self.assertIn("schema_version must be 438",validate_v438({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v438({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v438({}),[])
if __name__=="__main__":unittest.main()
