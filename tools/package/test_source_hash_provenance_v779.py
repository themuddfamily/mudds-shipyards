import unittest
from tools.package.source_hash_provenance_v779 import validate_v779
class V779Test(unittest.TestCase):
 def test_valid(self):self.assertEqual(validate_v779({"schema_version":779}),[])
 def test_schema(self):self.assertIn("schema_version must be 779",validate_v779({"schema_version":423})[0])
 def test_label(self):self.assertTrue(validate_v779({},"x"))
 def test_fourth(self):self.assertNotEqual(validate_v779({}),[])
if __name__=="__main__":unittest.main()
