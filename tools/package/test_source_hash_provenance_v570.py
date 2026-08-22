import unittest
from tools.package.source_hash_provenance_v570 import validate_v570
class V570Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v570({})))
 def test_schema(self):self.assertIn("schema_version must be 570",validate_v570({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v570({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v570({}),[])
if __name__=="__main__":unittest.main()
