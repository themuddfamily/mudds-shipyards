import unittest
from tools.package.source_hash_provenance_v614 import validate_v614
class V614Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v614({"schema_version":614}),[])
 def test_schema(self):self.assertIn("schema_version must be 614",validate_v614({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v614({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v614({}),[])
if __name__=="__main__":unittest.main()
