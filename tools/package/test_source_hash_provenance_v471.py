import unittest
from tools.package.source_hash_provenance_v471 import validate_v471
class V471Test(unittest.TestCase):
 def test_valid(self):self.assertTrue(any("schema_version" in e for e in validate_v471({})))
 def test_schema(self):self.assertIn("schema_version must be 471",validate_v471({"schema_version":423}))
 def test_label(self):self.assertTrue(validate_v471({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v471({}),[])
if __name__=="__main__":unittest.main()
