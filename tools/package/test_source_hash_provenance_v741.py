import unittest
from tools.package.source_hash_provenance_v741 import validate_v741
class V741Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v741({"schema_version":741}),[])
 def test_schema(self):self.assertIn("schema_version must be 741",validate_v741({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v741({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v741({}),[])
if __name__=="__main__":unittest.main()
