import unittest
from tools.package.source_hash_provenance_v743 import validate_v743
class V743Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v743({"schema_version":743}),[])
 def test_schema(self):self.assertIn("schema_version must be 743",validate_v743({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v743({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v743({}),[])
if __name__=="__main__":unittest.main()
