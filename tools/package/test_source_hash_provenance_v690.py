import unittest
from tools.package.source_hash_provenance_v690 import validate_v690
class V690Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v690({"schema_version":690}),[])
 def test_schema(self):self.assertIn("schema_version must be 690",validate_v690({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v690({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v690({}),[])
if __name__=="__main__":unittest.main()
