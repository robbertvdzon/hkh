#!/usr/bin/env python3
"""Select image components from a newline-delimited Git diff."""
import json
import os
import sys

paths = sys.stdin.read().splitlines()
force = os.environ.get('GITHUB_EVENT_NAME') in ('pull_request', 'workflow_dispatch')
workflow = any(p.startswith('.github/') for p in paths)
components = [('backend', 'backend'), ('frontend', 'frontend'), ('admin', 'frontend-admin')]
selected = [dict(image=image, context=context) for image, context in components
            if force or workflow or any(p.startswith(context + '/') for p in paths)]
with open(os.environ['GITHUB_OUTPUT'], 'a') as out:
    out.write('matrix=' + json.dumps({'include': selected}) + '\n')
    out.write('any=' + str(bool(selected)).lower() + '\n')
    for image, _ in components:
        out.write(image + '=' + str(any(c['image'] == image for c in selected)).lower() + '\n')
