import unittest
from tools.package.source_hash_provenance_v561 import validate_v561
class V561Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v561({})))
 def test_schema(self):self.assertIn("schema_version must be 561",validate_v561({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v561({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v561({}),[])
if __name__=="__main__":unittest.main()
