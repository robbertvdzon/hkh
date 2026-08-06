#!/usr/bin/env python3
"""Vergelijk de twee fase-1-repositories, op expliciete runtime-identiteit na."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path


IGNORED_PARTS = {
    ".git",
    ".dart_tool",
    ".idea",
    "build",
    "target",
}
IGNORED_FILES = {
    ".DS_Store",
    "secrets.env",
    "secrets-cluster.env",
    "local.properties",
}
IDENTITY_PATHS = {
    ".github/workflows/build-apk.yml",
    "README.md",
    "backend/src/main/resources/application.properties",
    "deploy/README.md",
    "deploy/argocd/application.yaml",
    "deploy/base/sealed-secret-runtime.yaml",
    "deploy/overlays/openshift/kustomization.yaml",
    "deploy/seal-secrets.sh",
    "deploy/secrets-cluster.env.example",
    "docker-compose.dev.yml",
    "docs/deployment.md",
    "frontend/android/app/build.gradle.kts",
    "frontend/android/app/src/main/AndroidManifest.xml",
    "secrets.env.example",
}
IDENTITY_PREFIXES = {
    "frontend/android/app/src/main/kotlin/",
}


def is_identity(path: str) -> bool:
    return path in IDENTITY_PATHS or any(path.startswith(prefix) for prefix in IDENTITY_PREFIXES)


def snapshot(root: Path) -> dict[str, str]:
    files: dict[str, str] = {}
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if not path.is_file() or any(part in IGNORED_PARTS for part in relative.parts):
            continue
        if path.name in IGNORED_FILES:
            continue
        relative_text = relative.as_posix()
        if is_identity(relative_text):
            continue
        files[relative_text] = hashlib.sha256(path.read_bytes()).hexdigest()
    return files


def main() -> int:
    left = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1])
    right = Path(sys.argv[2] if len(sys.argv) > 2 else left.parent / "hkh-autopilot")
    left_snapshot = snapshot(left)
    right_snapshot = snapshot(right)
    different = sorted(
        path
        for path in left_snapshot.keys() | right_snapshot.keys()
        if left_snapshot.get(path) != right_snapshot.get(path)
    )
    if different:
        print("Niet-toegestane baselineverschillen:", file=sys.stderr)
        for path in different:
            print(f"- {path}", file=sys.stderr)
        return 1
    print(f"Baselinepariteit groen: {len(left_snapshot)} identieke bestanden gecontroleerd.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
