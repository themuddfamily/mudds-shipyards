import unittest
from tools.package.source_hash_provenance_v480 import validate_v480
class V480Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v480({})))
 def test_schema(self):self.assertIn("schema_version must be 480",validate_v480({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v480({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v480({}),[])
if __name__=="__main__":unittest.main()
