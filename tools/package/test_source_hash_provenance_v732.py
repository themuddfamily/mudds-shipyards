import unittest
from tools.package.source_hash_provenance_v732 import validate_v732
class V732Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v732({"schema_version":732}),[])
 def test_schema(self):self.assertIn("schema_version must be 732",validate_v732({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v732({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v732({}),[])
if __name__=="__main__":unittest.main()
