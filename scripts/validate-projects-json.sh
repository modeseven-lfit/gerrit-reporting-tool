#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
#
# validate-projects-json.sh
#
# Purpose:
# - Validate the schema of a projects JSON file (default: testing/projects.json)
# - This reflects the updated schema:
#   * Supports GitHub-only projects (no 'gerrit' required)
#   * Adds Jenkins authentication fields: 'jenkins_user' and 'jenkins_token'
#     - If one is present, both must be present and non-empty strings
#   * Optional 'jjb_attribution' object with fields: url (string), branch (string), enabled (boolean)
#
# Exit codes:
#  0 - Valid JSON and schema
#  1 - File not found / unreadable
#  2 - Invalid JSON syntax
#  3 - Schema validation failed

set -euo pipefail

PROJECTS_JSON_PATH="${1:-testing/projects.json}"

log_info()  { printf "ℹ️  %s\n" "$*"; }
log_ok()    { printf "✅ %s\n" "$*"; }
log_error() { printf "::error::%s\n" "$*"; }

if ! command -v jq >/dev/null 2>&1; then
  log_error "jq is required but not installed or not on PATH"
  exit 1
fi

if [[ ! -r "$PROJECTS_JSON_PATH" ]]; then
  log_error "Projects JSON file not found or not readable: $PROJECTS_JSON_PATH"
  exit 1
fi

log_info "Validating JSON syntax: $PROJECTS_JSON_PATH"
if ! jq . "$PROJECTS_JSON_PATH" >/dev/null 2>&1; then
  log_error "Invalid JSON syntax in: $PROJECTS_JSON_PATH"
  exit 2
fi
log_ok "JSON syntax is valid"

# jq program to validate schema and emit detailed error messages
# Rules:
#  - Root is an array
#  - Each item:
#      required: project (string), slug (string)
#      optional: gerrit (string), jenkins (string), github (string)
#      optional: jjb_attribution (object) -> url(string), branch(string), enabled(boolean)
#      jenkins auth: if jenkins_user or jenkins_token present then both must be present and non-empty strings
# shellcheck disable=SC2016
JQ_VALIDATE='
def is_string: type == "string";
def is_bool: type == "boolean";

def non_empty_string: (is_string and (length > 0));

def validate_jjb_attr:
  if has("jjb_attribution") then
    if .jjb_attribution == null then
      {ok: false, reason: "jjb_attribution must be an object, not null"}
    elif (.jjb_attribution | type) != "object" then
      {ok: false, reason: "jjb_attribution must be an object"}
    else
      ( .jjb_attribution as $jjb
        | if ($jjb | has("url") | not) then
            {ok: false, reason: "jjb_attribution.url is required"}
          elif ($jjb.url | is_string | not) then
            {ok: false, reason: "jjb_attribution.url must be a string"}
          elif ($jjb | has("branch") | not) then
            {ok: false, reason: "jjb_attribution.branch is required"}
          elif ($jjb.branch | is_string | not) then
            {ok: false, reason: "jjb_attribution.branch must be a string"}
          elif ($jjb | has("enabled") | not) then
            {ok: false, reason: "jjb_attribution.enabled is required"}
          elif ($jjb.enabled | is_bool | not) then
            {ok: false, reason: "jjb_attribution.enabled must be a boolean"}
          else
            {ok: true}
          end
      )
    end
  else
    {ok: true}
  end;

def validate_jenkins_auth:
  # If either auth field is present, both must be present and non-empty strings
  ( (has("jenkins_user") or has("jenkins_token")) as $has_any
    | if $has_any then
        if (has("jenkins_user") | not) then
          {ok: false, reason: "jenkins_user is required when jenkins_token is present"}
        elif (has("jenkins_token") | not) then
          {ok: false, reason: "jenkins_token is required when jenkins_user is present"}
        elif (.jenkins_user | non_empty_string | not) then
          {ok: false, reason: "jenkins_user must be a non-empty string"}
        elif (.jenkins_token | non_empty_string | not) then
          {ok: false, reason: "jenkins_token must be a non-empty string"}
        else
          {ok: true}
        end
      else
        {ok: true}
      end
  );

def validate_optional_strings:
  # Optional fields, but if present must be strings
  if (has("gerrit") and (.gerrit | is_string | not)) then
    {ok: false, reason: "gerrit must be a string when present"}
  elif (has("jenkins") and (.jenkins | is_string | not)) then
    {ok: false, reason: "jenkins must be a string when present"}
  elif (has("github") and (.github | is_string | not)) then
    {ok: false, reason: "github must be a string when present"}
  else
    {ok: true}
  end;

def validate_required:
  if (has("project") | not) then
    {ok: false, reason: "project is required"}
  elif (.project | is_string | not) then
    {ok: false, reason: "project must be a string"}
  elif (has("slug") | not) then
    {ok: false, reason: "slug is required"}
  elif (.slug | is_string | not) then
    {ok: false, reason: "slug must be a string"}
  else
    {ok: true}
  end;

def validate_item:
  ( validate_required as $req
  | if ($req.ok | not) then $req
    else
      ( validate_optional_strings as $opt
      | if ($opt.ok | not) then $opt
        else
          ( validate_jjb_attr as $jjb
          | if ($jjb.ok | not) then $jjb
            else
              ( validate_jenkins_auth )
            end
          )
        end
      )
    end
  );

# Root must be an array
if (type != "array") then
  {root_ok: false, root_reason: "Root must be an array"}
else
  {root_ok: true}
end as $root;

# Collect per-item validation results with index and slugs
def with_index:
  to_entries
  | map({
      index: .key,
      value: .value,
      project: (.value.project // ""),
      slug: (.value.slug // "")
    });

. as $root_array
| [$root_array | with_index
    | map({
        index,
        project,
        slug,
        result: ( .value | validate_item )
      })
  ] as $checks

| {
    root_ok: $root.root_ok,
    root_reason: ($root.root_reason // null),
    failures: ($checks[0]
      | map(select(.result.ok | not)
            | {
                index,
                project,
                slug,
                reason: .result.reason
              }
        )
    ),
    total: ($root_array | length),
    passed: ($checks[0] | map(.result.ok) | map(select(.)) | length)
  }
'

log_info "Running schema checks (supports GitHub-only projects and Jenkins auth)"
RESULT_JSON="$(jq -c "$JQ_VALIDATE" "$PROJECTS_JSON_PATH")"

ROOT_OK="$(jq -r '.root_ok' <<<"$RESULT_JSON")"
if [[ "$ROOT_OK" != "true" ]]; then
  REASON="$(jq -r '.root_reason' <<<"$RESULT_JSON")"
  log_error "Schema error: $REASON"
  exit 3
fi

TOTAL="$(jq -r '.total' <<<"$RESULT_JSON")"
PASSED="$(jq -r '.passed' <<<"$RESULT_JSON")"
FAIL_COUNT=$((TOTAL - PASSED))

if (( FAIL_COUNT > 0 )); then
  log_error "Schema validation failed for $FAIL_COUNT of $TOTAL project(s)"
  log_info "Details:"
  jq -r '
    .failures[]
    | "- [index=\(.index)] project=\"\(.project)\" slug=\"\(.slug)\": \(.reason)"
  ' <<<"$RESULT_JSON"
  exit 3
fi

log_ok "Schema validation passed for all $TOTAL project(s)"

# Optional: print a short summary list
echo
log_info "Projects parsed:"
jq -r '
  . as $arr
  | if (type == "array") then
      $arr[] | [
        (.project // "(missing project)"),
        (.slug // "(missing slug)"),
        (.gerrit // "(github-only)"),
        (.jenkins // "(no jenkins)"),
        (.github // "(no github)")
      ] | @tsv
    else
      empty
    end
' "$PROJECTS_JSON_PATH" \
| awk -F'\t' 'BEGIN { printf "  %-28s %-16s %-28s %-28s %-20s\n", "PROJECT", "SLUG", "GERRIT", "JENKINS", "GITHUB"; print "  " sprintf("%0*d", 120, 0) gsub(/0/,"-",x) } { printf "  %-28s %-16s %-28s %-28s %-20s\n", $1, $2, $3, $4, $5 }'

exit 0
