import unittest
from tools.package.source_hash_provenance_v512 import validate_v512
class V512Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v512({})))
 def test_schema(self):self.assertIn("schema_version must be 512",validate_v512({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v512({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v512({}),[])
if __name__=="__main__":unittest.main()
