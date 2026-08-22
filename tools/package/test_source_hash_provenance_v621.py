import unittest
from tools.package.source_hash_provenance_v621 import validate_v621
class V621Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v621({"schema_version":621}),[])
 def test_schema(self):self.assertIn("schema_version must be 621",validate_v621({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v621({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v621({}),[])
if __name__=="__main__":unittest.main()
