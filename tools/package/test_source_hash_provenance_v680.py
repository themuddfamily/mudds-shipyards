import unittest
from tools.package.source_hash_provenance_v680 import validate_v680
class V680Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v680({"schema_version":680}),[])
 def test_schema(self):self.assertIn("schema_version must be 680",validate_v680({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v680({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v680({}),[])
if __name__=="__main__":unittest.main()
