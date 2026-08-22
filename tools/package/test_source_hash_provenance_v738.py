import unittest
from tools.package.source_hash_provenance_v738 import validate_v738
class V738Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v738({"schema_version":738}),[])
 def test_schema(self):self.assertIn("schema_version must be 738",validate_v738({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v738({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v738({}),[])
if __name__=="__main__":unittest.main()
