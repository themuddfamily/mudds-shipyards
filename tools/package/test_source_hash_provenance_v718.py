import unittest
from tools.package.source_hash_provenance_v718 import validate_v718
class V718Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v718({"schema_version":718}),[])
 def test_schema(self):self.assertIn("schema_version must be 718",validate_v718({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v718({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v718({}),[])
if __name__=="__main__":unittest.main()
