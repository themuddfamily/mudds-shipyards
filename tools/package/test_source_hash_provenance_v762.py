import unittest
from tools.package.source_hash_provenance_v762 import validate_v762
class V762Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v762({"schema_version":762}),[])
 def test_schema(self):self.assertIn("schema_version must be 762",validate_v762({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v762({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v762({}),[])
if __name__=="__main__":unittest.main()
