import unittest
from tools.package.source_hash_provenance_v573 import validate_v573
class V573Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v573({})))
 def test_schema(self):self.assertIn("schema_version must be 573",validate_v573({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v573({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v573({}),[])
if __name__=="__main__":unittest.main()
