import unittest
from tools.package.source_hash_provenance_v777 import validate_v777
class V777Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v777({"schema_version":777}),[])
 def test_schema(self):self.assertIn("schema_version must be 777",validate_v777({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v777({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v777({}),[])
if __name__=="__main__":unittest.main()
