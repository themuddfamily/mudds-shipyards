import unittest
from tools.package.source_hash_provenance_v464 import validate_v464
class V464Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v464({})))
 def test_schema(self):self.assertIn("schema_version must be 464",validate_v464({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v464({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v464({}),[])
if __name__=="__main__":unittest.main()
