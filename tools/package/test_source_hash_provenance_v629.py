import unittest
from tools.package.source_hash_provenance_v629 import validate_v629
class V629Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v629({"schema_version":629}),[])
 def test_schema(self):self.assertIn("schema_version must be 629",validate_v629({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v629({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v629({}),[])
if __name__=="__main__":unittest.main()
