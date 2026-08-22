import unittest
from tools.package.source_hash_provenance_v589 import validate_v589
class V589Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v589({"schema_version":589}),[])
 def test_schema(self):self.assertIn("schema_version must be 589",validate_v589({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v589({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v589({}),[])
if __name__=="__main__":unittest.main()
