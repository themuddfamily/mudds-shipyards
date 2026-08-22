import unittest
from tools.package.source_hash_provenance_v580 import validate_v580
class V580Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v580({})))
 def test_schema(self):self.assertIn("schema_version must be 580",validate_v580({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v580({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v580({}),[])
if __name__=="__main__":unittest.main()
