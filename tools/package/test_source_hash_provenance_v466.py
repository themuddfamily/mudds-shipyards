import unittest
from tools.package.source_hash_provenance_v466 import validate_v466
class V466Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v466({})))
 def test_schema(self):self.assertIn("schema_version must be 466",validate_v466({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v466({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v466({}),[])
if __name__=="__main__":unittest.main()
