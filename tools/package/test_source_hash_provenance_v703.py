import unittest
from tools.package.source_hash_provenance_v703 import validate_v703
class V703Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v703({"schema_version":703}),[])
 def test_schema(self):self.assertIn("schema_version must be 703",validate_v703({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v703({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v703({}),[])
if __name__=="__main__":unittest.main()
