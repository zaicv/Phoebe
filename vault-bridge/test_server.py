import tempfile
import unittest
from pathlib import Path

from server import VideoIndex, normalize_relative_path


class NormalizePathTests(unittest.TestCase):
    def test_normalizes_clean_path(self):
        self.assertEqual(normalize_relative_path("movies/action"), "movies/action")

    def test_rejects_traversal(self):
        with self.assertRaises(ValueError):
            normalize_relative_path("../secrets")

        with self.assertRaises(ValueError):
            normalize_relative_path("movies/%2e%2e/private")


class IndexTests(unittest.TestCase):
    def test_index_stability(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            video = root / "clip.mp4"
            video.write_bytes(b"hello world")

            index = VideoIndex(root)
            index.rebuild()
            first = next(iter(index._by_id.values())).id

            index.rebuild()
            second = next(iter(index._by_id.values())).id

            self.assertEqual(first, second)

    def test_library_and_search(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "Trips").mkdir()
            (root / "Trips" / "beach.mov").write_bytes(b"12345")

            index = VideoIndex(root)
            index.rebuild()

            folders, files = index.list_path("")
            self.assertEqual(folders[0]["name"], "Trips")
            self.assertEqual(files, [])

            results = index.search("beach", "Trips")
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["filename"], "beach.mov")


if __name__ == "__main__":
    unittest.main()
