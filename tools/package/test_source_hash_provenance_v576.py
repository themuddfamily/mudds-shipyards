import unittest
from tools.package.source_hash_provenance_v576 import validate_v576
class V576Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v576({})))
 def test_schema(self):self.assertIn("schema_version must be 576",validate_v576({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v576({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v576({}),[])
if __name__=="__main__":unittest.main()
