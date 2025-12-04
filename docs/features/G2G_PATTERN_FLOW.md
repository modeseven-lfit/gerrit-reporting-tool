<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# G2G Pattern Matching Flow Diagram

## Overview

This document provides visual representations of how the G2G (GitHub2Gerrit) workflow detection system processes configuration patterns and matches workflow files.

## Configuration Processing Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Project Configuration File                    │
│                  (e.g., opendaylight.yaml)                       │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
                 ┌────────────────────┐
                 │  Load Configuration│
                 │  features.g2g      │
                 └─────────┬──────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │  Extract workflow_files List            │
        │  Default: ["github2gerrit.yaml",        │
        │            "call-github2gerrit.yaml"]   │
        └─────────────────┬───────────────────────┘
                          │
                          ▼
              ┌──────────────────────────┐
              │  Is it a string?         │
              │  Convert to list         │
              └───────────┬──────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │  Separate Patterns by Type              │
        └─────────────────┬───────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            │                           │
            ▼                           ▼
  ┌──────────────────┐       ┌──────────────────────┐
  │  Exact Filenames │       │  Regex Patterns      │
  │  (no prefix)     │       │  (starts with        │
  │                  │       │   "regex:")          │
  └──────┬───────────┘       └──────────┬───────────┘
         │                              │
         └──────────┬───────────────────┘
                    │
                    ▼
       ┌────────────────────────┐
       │  Pattern Matching      │
       │  Process               │
       └────────────────────────┘
```

## Pattern Matching Process

```text
┌────────────────────────────────────────────────────────────────┐
│              Check .github/workflows/ Directory                 │
└────────────────────────┬───────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────────┐
            │  Directory exists?         │
            └────────────┬───────────────┘
                         │
            ┌────────────┴────────────┐
            │ NO                      │ YES
            ▼                         ▼
   ┌─────────────────┐    ┌──────────────────────────┐
   │  Return Empty   │    │  Process Pattern Types   │
   │  Result         │    └──────────┬───────────────┘
   └─────────────────┘               │
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
                    ▼                                 ▼
        ┌───────────────────────┐      ┌──────────────────────────┐
        │  EXACT FILENAMES      │      │  REGEX PATTERNS          │
        └───────────┬───────────┘      └──────────┬───────────────┘
                    │                             │
                    ▼                             ▼
        ┌───────────────────────┐      ┌──────────────────────────┐
        │  For each filename:   │      │  Compile each pattern:   │
        │  - Check if file      │      │  - Add re.IGNORECASE     │
        │    exists             │      │  - Handle errors         │
        │  - Add to found_files │      │  - Skip invalid patterns │
        └───────────┬───────────┘      └──────────┬───────────────┘
                    │                             │
                    │                             ▼
                    │              ┌──────────────────────────────┐
                    │              │  Get all workflow files:     │
                    │              │  - List .github/workflows/   │
                    │              │  - Exclude hidden files      │
                    │              │  - Exclude directories       │
                    │              └──────────┬───────────────────┘
                    │                         │
                    │                         ▼
                    │              ┌──────────────────────────────┐
                    │              │  For each workflow file:     │
                    │              │  - Test against each pattern │
                    │              │  - Add matches to found_files│
                    │              │  - Track pattern matches     │
                    │              └──────────┬───────────────────┘
                    │                         │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌────────────────────────────┐
                    │  Deduplicate Results       │
                    │  (same file matched by     │
                    │   multiple patterns)       │
                    └────────────┬───────────────┘
                                 │
                                 ▼
                    ┌────────────────────────────┐
                    │  Sort Results              │
                    │  (alphabetical order)      │
                    └────────────┬───────────────┘
                                 │
                                 ▼
                    ┌────────────────────────────┐
                    │  Return Result Object      │
                    │  - present: bool           │
                    │  - file_paths: list        │
                    │  - file_path: str          │
                    │  - matched_patterns: dict  │
                    └────────────────────────────┘
```

## Example: OpenDaylight Configuration Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│  OpenDaylight Configuration                                      │
│  ────────────────────────────                                    │
│  features:                                                       │
│    g2g:                                                          │
│      workflow_files:                                             │
│        - "regex:.*github2gerrit.*"                               │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │  Parse Pattern              │
            │  "regex:.*github2gerrit.*"  │
            └─────────────┬───────────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │  Remove "regex:" prefix     │
            │  Pattern: ".*github2gerrit.*"│
            └─────────────┬───────────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │  Compile Regex              │
            │  Flags: re.IGNORECASE       │
            └─────────────┬───────────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │  Scan .github/workflows/    │
            │  Found:                     │
            │  - ci-verify.yaml           │
            │  - github2gerrit.yaml       │
            │  - call-github2gerrit.yaml  │
            │  - call-composed-           │
            │    github2gerrit.yaml       │
            │  - release.yaml             │
            └─────────────┬───────────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │  Test Each File Against     │
            │  Pattern                    │
            └─────────────┬───────────────┘
                          │
            ┌─────────────┼─────────────┐
            │             │             │
            ▼             ▼             ▼
     ┌──────────┐  ┌──────────┐  ┌──────────┐
     │ ci-verify│  │ github2  │  │ release  │
     │  .yaml   │  │ gerrit   │  │  .yaml   │
     │          │  │  .yaml   │  │          │
     │ ❌ SKIP  │  │ ✅ MATCH │  │ ❌ SKIP  │
     └──────────┘  └──────────┘  └──────────┘
                          │
            ┌─────────────┼─────────────┐
            │             │             │
            ▼             ▼             ▼
     ┌──────────┐  ┌──────────┐  ┌──────────┐
     │   call-  │  │   call-  │  │          │
     │  github2 │  │ composed-│  │          │
     │  gerrit  │  │ github2  │  │          │
     │  .yaml   │  │ gerrit   │  │          │
     │ ✅ MATCH │  │  .yaml   │  │          │
     │          │  │ ✅ MATCH │  │          │
     └──────────┘  └──────────┘  └──────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │  Matched Files:             │
            │  1. github2gerrit.yaml      │
            │  2. call-github2gerrit.yaml │
            │  3. call-composed-          │
            │     github2gerrit.yaml      │
            └─────────────┬───────────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │  Sort Alphabetically        │
            └─────────────┬───────────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │  Return Result:             │
            │  {                          │
            │    "present": true,         │
            │    "file_paths": [          │
            │      ".github/workflows/    │
            │       call-composed-        │
            │       github2gerrit.yaml",  │
            │      ".github/workflows/    │
            │       call-github2gerrit.   │
            │       yaml",                │
            │      ".github/workflows/    │
            │       github2gerrit.yaml"   │
            │    ],                       │
            │    "file_path": ".github/   │
            │     workflows/call-composed-│
            │     github2gerrit.yaml",    │
            │    "matched_patterns": {    │
            │      "regex:.*github2gerrit │
            │      .*": [                 │
            │        "github2gerrit.yaml",│
            │        "call-github2gerrit. │
            │        yaml",                │
            │        "call-composed-      │
            │        github2gerrit.yaml"  │
            │      ]                      │
            │    }                        │
            │  }                          │
            └─────────────────────────────┘
```

## Pattern Type Decision Tree

```text
                    ┌─────────────────────┐
                    │  Pattern String     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Starts with         │
                    │  "regex:"?           │
                    └──────────┬───────────┘
                               │
                ┌──────────────┴──────────────┐
                │ YES                         │ NO
                ▼                             ▼
    ┌───────────────────────┐    ┌───────────────────────┐
    │  REGEX PATTERN        │    │  EXACT FILENAME       │
    └───────────┬───────────┘    └───────────┬───────────┘
                │                             │
                ▼                             ▼
    ┌───────────────────────┐    ┌───────────────────────┐
    │  Remove "regex:"      │    │  Check if file exists │
    │  prefix               │    │  in workflows/        │
    └───────────┬───────────┘    └───────────┬───────────┘
                │                             │
                ▼                             │
    ┌───────────────────────┐                │
    │  Compile with         │                │
    │  re.IGNORECASE        │                │
    └───────────┬───────────┘                │
                │                             │
                ▼                             │
    ┌───────────────────────┐                │
    │  Valid regex?         │                │
    └───────────┬───────────┘                │
                │                             │
    ┌───────────┴───────────┐                │
    │ YES                   │ NO             │
    ▼                       ▼                 │
┌────────────┐    ┌──────────────┐           │
│  Test all  │    │  Log warning │           │
│  workflow  │    │  Skip pattern│           │
│  files     │    └──────────────┘           │
└─────┬──────┘                               │
      │                                      │
      └──────────────┬───────────────────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │  Add matches to        │
        │  found_files list      │
        └────────────────────────┘
```

## Mixed Configuration Example

```text
Configuration:
┌──────────────────────────────────────────┐
│  workflow_files:                         │
│    - "exact-workflow.yaml"               │
│    - "regex:.*github2gerrit.*"           │
│    - "another-exact.yaml"                │
└──────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  Separate by Type     │
        └───────────┬───────────┘
                    │
        ┌───────────┴───────────────────┐
        │                               │
        ▼                               ▼
┌─────────────────┐         ┌─────────────────────┐
│ EXACT:          │         │ REGEX:              │
│ - exact-        │         │ - .*github2gerrit.* │
│   workflow.yaml │         └─────────┬───────────┘
│ - another-      │                   │
│   exact.yaml    │                   ▼
└────────┬────────┘         ┌─────────────────────┐
         │                  │ Match against all   │
         │                  │ workflow files      │
         │                  └─────────┬───────────┘
         │                            │
         └──────────┬─────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  Combine Results      │
        │  Deduplicate          │
        │  Sort                 │
        └───────────┬───────────┘
                    │
                    ▼
            ┌───────────────┐
            │  Final Result │
            └───────────────┘
```

## Error Handling Flow

```text
                    ┌─────────────────┐
                    │  Process Pattern│
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Is regex?      │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │ YES             │ NO
                    ▼                 ▼
        ┌───────────────────┐  ┌──────────────┐
        │  Compile Pattern  │  │  Check File  │
        └───────┬───────────┘  │  Exists      │
                │              └──────────────┘
                ▼
        ┌───────────────────┐
        │  Compilation      │
        │  Successful?      │
        └───────┬───────────┘
                │
    ┌───────────┴───────────┐
    │ YES                   │ NO
    ▼                       ▼
┌────────────┐    ┌──────────────────────┐
│  Use       │    │  Log Warning:        │
│  Pattern   │    │  "Invalid regex      │
│            │    │   pattern: <pattern>"│
└────────────┘    └──────────┬───────────┘
                              │
                              ▼
                  ┌─────────────────────────┐
                  │  Skip Pattern           │
                  │  Continue Processing    │
                  │  Other Patterns         │
                  └─────────────────────────┘
```

## Case Sensitivity Flow

```text
Pattern: "regex:.*github2gerrit.*"
                    │
                    ▼
        ┌───────────────────────┐
        │  Check for (?-i)      │
        │  flag in pattern      │
        └───────────┬───────────┘
                    │
        ┌───────────┴───────────┐
        │ FOUND                 │ NOT FOUND
        ▼                       ▼
┌─────────────────┐   ┌─────────────────────┐
│  Case-sensitive │   │  Case-insensitive   │
│  Matching       │   │  Matching (default) │
└────────┬────────┘   └────────┬────────────┘
         │                     │
         ▼                     ▼
┌─────────────────┐   ┌─────────────────────┐
│  Matches:       │   │  Matches:           │
│  - github2gerrit│   │  - github2gerrit    │
│  (exact case)   │   │  - GitHub2Gerrit    │
│                 │   │  - GITHUB2GERRIT    │
│                 │   │  - GiThUb2gErRiT    │
└─────────────────┘   └─────────────────────┘
```

## Performance Optimization

```text
┌─────────────────────────────────────────┐
│  Optimization Strategies                 │
└─────────────────────────────────────────┘

1. Pattern Compilation
   ┌──────────────────────────────────┐
   │  Compile Once                    │
   │  ↓                               │
   │  Store compiled regex object     │
   │  ↓                               │
   │  Reuse for all files             │
   └──────────────────────────────────┘

2. Early Exit for Exact Matches
   ┌──────────────────────────────────┐
   │  Check exact filenames first     │
   │  ↓                               │
   │  Only scan directory if regex    │
   │  patterns present                │
   └──────────────────────────────────┘

3. Invalid Pattern Handling
   ┌──────────────────────────────────┐
   │  Catch compilation errors        │
   │  ↓                               │
   │  Log warning                     │
   │  ↓                               │
   │  Skip immediately (don't retry)  │
   └──────────────────────────────────┘

4. Directory Scanning
   ┌──────────────────────────────────┐
   │  Single directory scan           │
   │  ↓                               │
   │  Filter files once               │
   │  ↓                               │
   │  Test against all patterns       │
   └──────────────────────────────────┘

5. Deduplication
   ┌──────────────────────────────────┐
   │  Use set for found files         │
   │  ↓                               │
   │  Convert to sorted list at end   │
   └──────────────────────────────────┘
```

## Result Structure Visualization

```text
Result Object:
┌─────────────────────────────────────────────────────────────┐
│  {                                                          │
│    "present": bool,  ───────────► Whether any matches found│
│                                                             │
│    "file_paths": [   ───────────► All matched files        │
│      ".github/workflows/file1.yaml",                       │
│      ".github/workflows/file2.yaml"                        │
│    ],                                                       │
│                                                             │
│    "file_path": str, ───────────► First match (backward   │
│                                    compatibility)           │
│                                                             │
│    "matched_patterns": { ───────► Pattern matching detail  │
│      "regex:.*g2g.*": [                                    │
│        "file1.yaml",                                       │
│        "file2.yaml"                                        │
│      ],                                                     │
│      "exact.yaml": [                                       │
│        "exact.yaml"                                        │
│      ]                                                      │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
```

## Summary

This visual guide demonstrates:

1. **Configuration Processing**: How patterns are loaded and parsed
2. **Pattern Matching**: How files are tested against patterns
3. **Mixed Configurations**: How exact and regex patterns work together
4. **Error Handling**: How invalid patterns are managed
5. **Case Sensitivity**: Default behavior and overrides
6. **Performance**: Optimization strategies
7. **Results**: Structure and metadata returned

These flows ensure reliable, efficient, and maintainable workflow detection for the G2G feature.
