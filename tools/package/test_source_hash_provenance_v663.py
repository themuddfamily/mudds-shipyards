import unittest
from tools.package.source_hash_provenance_v663 import validate_v663
class V663Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v663({"schema_version":663}),[])
 def test_schema(self):self.assertIn("schema_version must be 663",validate_v663({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v663({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v663({}),[])
if __name__=="__main__":unittest.main()
