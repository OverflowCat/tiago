#!/usr/bin/env python3
"""Add Apache 2.0 license headers to MoonBit source files."""

import os
import glob
import argparse

LICENSE_HEADER = """// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

"""

SKIP_DIRS = [".mooncakes", "target"]


def should_skip(filepath: str) -> bool:
    """Check if filepath should be skipped."""
    for skip_dir in SKIP_DIRS:
        if f"/{skip_dir}/" in filepath:
            return True
    return False


def add_headers(root: str, dry_run: bool = False) -> int:
    """Add license headers to all .mbt files under root."""
    count = 0

    for filepath in glob.glob(os.path.join(root, "**/*.mbt"), recursive=True):
        if should_skip(filepath):
            continue

        with open(filepath, "r") as f:
            content = f.read()

        # Skip if already has the license header
        if content.startswith("// Copyright 2025"):
            print(f"Skipped (already has header): {os.path.relpath(filepath, root)}")
            continue

        if dry_run:
            print(f"Would add header: {os.path.relpath(filepath, root)}")
        else:
            with open(filepath, "w") as f:
                f.write(LICENSE_HEADER + content)
            print(f"Added header: {os.path.relpath(filepath, root)}")

        count += 1

    return count


def main():
    parser = argparse.ArgumentParser(description="Add license headers to MoonBit files")
    parser.add_argument("path", nargs="?", default=".", help="Root directory to process")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done")
    args = parser.parse_args()

    root = os.path.abspath(args.path)
    print(f"Processing: {root}\n")

    count = add_headers(root, args.dry_run)

    action = "Would update" if args.dry_run else "Updated"
    print(f"\n{action} {count} files")


if __name__ == "__main__":
    main()
