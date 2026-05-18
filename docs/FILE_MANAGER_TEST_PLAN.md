# File Manager Test Plan

Lyra changes should be checked against a small, repeatable file tree.

## Test tree

- Empty folder
- Folder with nested files
- Folder with spaces in the name
- Read-only file
- Large file over 100 MB

## Operations

- Copy and move files between folders.
- Rename files with spaces and mixed case.
- Delete only disposable test files.
- Refresh after external file changes.
- Search for names that include spaces, dots, and numbers.
