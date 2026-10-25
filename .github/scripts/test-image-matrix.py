#!/usr/bin/env python3
"""Regression checks for selective and forced component builds."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('image-matrix.py')

class MatrixTest(unittest.TestCase):
    def select(self, paths, event='push'):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            subprocess.run(['python3', str(SCRIPT)], input='\n'.join(paths), text=True,
                           env={**os.environ, 'GITHUB_EVENT_NAME': event,
                                'GITHUB_OUTPUT': str(output)}, check=True)
            values = dict(line.split('=', 1) for line in output.read_text().splitlines())
            return values, [row['image'] for row in json.loads(values['matrix'])['include']]

    def test_docs_need_no_images(self):
        values, images = self.select(['docs/deployment.md'])
        self.assertEqual(images, [])
        self.assertEqual(values['any'], 'false')

    def test_components_are_independent(self):
        self.assertEqual(self.select(['frontend-admin/lib/main.dart'])[1], ['admin'])
        self.assertEqual(self.select(['backend/pom.xml', 'frontend/lib/main.dart'])[1], ['backend', 'frontend'])

    def test_workflow_or_manual_or_pr_checks_all(self):
        for paths, event in [(['.github/scripts/image-matrix.py'], 'push'),
                             ([], 'workflow_dispatch'), (['README.md'], 'pull_request')]:
            self.assertEqual(self.select(paths, event)[1], ['backend', 'frontend', 'admin'])

if __name__ == '__main__':
    unittest.main()
