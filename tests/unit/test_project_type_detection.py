# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

"""Tests for project type detection in the FeatureRegistry."""

import logging
import tempfile
from pathlib import Path

import pytest

from project_reporting_tool.features.registry import FeatureRegistry


class TestProjectTypeDetection:
    """Test suite for project type detection."""

    @pytest.fixture
    def registry(self):
        """Create a FeatureRegistry instance."""
        config = {"features": {"enabled": ["project_types"]}}
        logger = logging.getLogger("test")
        return FeatureRegistry(config, logger)

    @pytest.fixture
    def temp_repo(self):
        """Create a temporary repository directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            yield Path(tmpdir)

    def test_detect_javascript(self, registry, temp_repo):
        """Test JavaScript project detection."""
        # Create package.json
        (temp_repo / "package.json").write_text('{"name": "test"}')
        (temp_repo / "index.js").write_text("console.log('test');")

        result = registry._check_project_types(temp_repo)

        assert "JavaScript" in result["detected_types"]
        assert result["primary_type"] in ["JavaScript", "Node"]

    def test_detect_typescript(self, registry, temp_repo):
        """Test TypeScript project detection."""
        (temp_repo / "tsconfig.json").write_text('{"compilerOptions": {}}')
        (temp_repo / "app.ts").write_text("const x: string = 'test';")

        result = registry._check_project_types(temp_repo)

        assert "TypeScript" in result["detected_types"]

    def test_detect_python(self, registry, temp_repo):
        """Test Python project detection."""
        (temp_repo / "setup.py").write_text("from setuptools import setup")
        (temp_repo / "main.py").write_text("print('test')")

        result = registry._check_project_types(temp_repo)

        assert "Python" in result["detected_types"]
        assert result["primary_type"] == "Python"

    def test_detect_python_pyproject(self, registry, temp_repo):
        """Test Python project detection with pyproject.toml."""
        (temp_repo / "pyproject.toml").write_text("[tool.poetry]")

        result = registry._check_project_types(temp_repo)

        assert "Python" in result["detected_types"]

    def test_detect_maven(self, registry, temp_repo):
        """Test Maven project detection."""
        (temp_repo / "pom.xml").write_text("<project></project>")

        result = registry._check_project_types(temp_repo)

        assert "Java/Maven" in result["detected_types"]
        assert result["primary_type"] == "Java/Maven"

    def test_detect_gradle(self, registry, temp_repo):
        """Test Gradle project detection."""
        (temp_repo / "build.gradle").write_text("plugins { id 'java' }")

        result = registry._check_project_types(temp_repo)

        # build.gradle files are detected as both Groovy and Java/Gradle
        assert "Java/Gradle" in result["detected_types"] or "Groovy" in result["detected_types"]
        assert result["primary_type"] in ["Java/Gradle", "Groovy"]

    def test_detect_kotlin(self, registry, temp_repo):
        """Test Kotlin project detection."""
        (temp_repo / "Main.kt").write_text("fun main() { println('test') }")
        (temp_repo / "build.gradle.kts").write_text("plugins { kotlin('jvm') }")

        result = registry._check_project_types(temp_repo)

        # Kotlin is detected, and may also have Java/Gradle if gradle is detected
        assert "Kotlin" in result["detected_types"]

    def test_detect_groovy(self, registry, temp_repo):
        """Test Groovy project detection."""
        (temp_repo / "script.groovy").write_text("println 'test'")
        (temp_repo / "Jenkinsfile").write_text("pipeline { }")

        result = registry._check_project_types(temp_repo)

        assert "Groovy" in result["detected_types"]

    def test_detect_smarty(self, registry, temp_repo):
        """Test Smarty template detection."""
        (temp_repo / "template.tpl").write_text("{$variable}")
        (temp_repo / "smarty.conf").write_text("smarty_config")

        result = registry._check_project_types(temp_repo)

        assert "Smarty" in result["detected_types"]

    def test_detect_dockerfile(self, registry, temp_repo):
        """Test Dockerfile detection."""
        (temp_repo / "Dockerfile").write_text("FROM ubuntu:20.04")
        (temp_repo / "docker-compose.yml").write_text("version: '3'")

        result = registry._check_project_types(temp_repo)

        assert "Dockerfile" in result["detected_types"]

    def test_detect_ejs(self, registry, temp_repo):
        """Test EJS template detection."""
        (temp_repo / "template.ejs").write_text("<%= name %>")

        result = registry._check_project_types(temp_repo)

        assert "EJS" in result["detected_types"]

    def test_detect_robot_framework(self, registry, temp_repo):
        """Test Robot Framework detection."""
        (temp_repo / "test.robot").write_text("*** Test Cases ***")

        result = registry._check_project_types(temp_repo)

        assert "Robot Framework" in result["detected_types"]

    def test_detect_ruby(self, registry, temp_repo):
        """Test Ruby project detection."""
        (temp_repo / "Gemfile").write_text("source 'https://rubygems.org'")
        (temp_repo / "app.rb").write_text("puts 'test'")

        result = registry._check_project_types(temp_repo)

        assert "Ruby" in result["detected_types"]

    def test_detect_d_lang(self, registry, temp_repo):
        """Test D language detection."""
        (temp_repo / "main.d").write_text("void main() { }")

        result = registry._check_project_types(temp_repo)

        assert "D" in result["detected_types"]

    def test_detect_scala(self, registry, temp_repo):
        """Test Scala project detection."""
        (temp_repo / "build.sbt").write_text("name := 'test'")
        (temp_repo / "Main.scala").write_text("object Main extends App")

        result = registry._check_project_types(temp_repo)

        assert "Scala" in result["detected_types"]

    def test_detect_scss(self, registry, temp_repo):
        """Test SCSS detection."""
        (temp_repo / "styles.scss").write_text("$primary: blue;")

        result = registry._check_project_types(temp_repo)

        assert "SCSS" in result["detected_types"]

    def test_detect_html(self, registry, temp_repo):
        """Test HTML detection."""
        (temp_repo / "index.html").write_text("<html><body>Test</body></html>")

        result = registry._check_project_types(temp_repo)

        assert "HTML" in result["detected_types"]

    def test_detect_css(self, registry, temp_repo):
        """Test CSS detection."""
        (temp_repo / "style.css").write_text("body { color: red; }")

        result = registry._check_project_types(temp_repo)

        assert "CSS" in result["detected_types"]

    def test_detect_hcl(self, registry, temp_repo):
        """Test HCL/Terraform detection."""
        (temp_repo / "main.tf").write_text("resource 'aws_instance' 'example' { }")

        result = registry._check_project_types(temp_repo)

        assert "HCL" in result["detected_types"]

    def test_detect_clojure(self, registry, temp_repo):
        """Test Clojure detection."""
        (temp_repo / "core.clj").write_text("(defn main [] (println 'test'))")

        result = registry._check_project_types(temp_repo)

        assert "Clojure" in result["detected_types"]

    def test_detect_erlang(self, registry, temp_repo):
        """Test Erlang detection."""
        (temp_repo / "main.erl").write_text("-module(main).")
        (temp_repo / "rebar.config").write_text("{erl_opts, [debug_info]}.")

        result = registry._check_project_types(temp_repo)

        assert "Erlang" in result["detected_types"]

    def test_detect_lua(self, registry, temp_repo):
        """Test Lua detection."""
        (temp_repo / "script.lua").write_text("print('test')")

        result = registry._check_project_types(temp_repo)

        assert "Lua" in result["detected_types"]

    def test_detect_cpp(self, registry, temp_repo):
        """Test C++ detection."""
        (temp_repo / "main.cpp").write_text("#include <iostream>")
        (temp_repo / "CMakeLists.txt").write_text("cmake_minimum_required(VERSION 3.0)")

        result = registry._check_project_types(temp_repo)

        assert "C++" in result["detected_types"]

    def test_detect_c(self, registry, temp_repo):
        """Test C detection."""
        (temp_repo / "main.c").write_text("#include <stdio.h>")

        result = registry._check_project_types(temp_repo)

        assert "C" in result["detected_types"]

    def test_detect_plpgsql(self, registry, temp_repo):
        """Test PLpgSQL detection."""
        (temp_repo / "function.pgsql").write_text("CREATE FUNCTION test() RETURNS void")

        result = registry._check_project_types(temp_repo)

        assert "PLpgSQL" in result["detected_types"]

    def test_detect_rust(self, registry, temp_repo):
        """Test Rust detection."""
        (temp_repo / "Cargo.toml").write_text("[package]\nname = 'test'")
        (temp_repo / "main.rs").write_text("fn main() { }")

        result = registry._check_project_types(temp_repo)

        assert "Rust" in result["detected_types"]

    def test_detect_go(self, registry, temp_repo):
        """Test Go detection."""
        (temp_repo / "go.mod").write_text("module test")
        (temp_repo / "main.go").write_text("package main")

        result = registry._check_project_types(temp_repo)

        assert "Go" in result["detected_types"]

    def test_detect_java(self, registry, temp_repo):
        """Test Java detection with Ant."""
        (temp_repo / "build.xml").write_text("<project></project>")
        (temp_repo / "Main.java").write_text("public class Main { }")

        result = registry._check_project_types(temp_repo)

        assert "Java/Ant" in result["detected_types"] or "Java" in result["detected_types"]

    def test_detect_dotnet(self, registry, temp_repo):
        """Test .NET detection."""
        (temp_repo / "project.csproj").write_text("<Project></Project>")

        result = registry._check_project_types(temp_repo)

        assert ".NET" in result["detected_types"]

    def test_detect_php(self, registry, temp_repo):
        """Test PHP detection."""
        (temp_repo / "composer.json").write_text('{"require": {}}')
        (temp_repo / "index.php").write_text("<?php echo 'test'; ?>")

        result = registry._check_project_types(temp_repo)

        assert "PHP" in result["detected_types"]

    def test_detect_swift(self, registry, temp_repo):
        """Test Swift detection."""
        (temp_repo / "Package.swift").write_text("// swift-tools-version:5.0")
        (temp_repo / "main.swift").write_text("print('test')")

        result = registry._check_project_types(temp_repo)

        assert "Swift" in result["detected_types"]

    def test_detect_multiple_types(self, registry, temp_repo):
        """Test detection of multiple project types."""
        (temp_repo / "package.json").write_text('{"name": "test"}')
        (temp_repo / "tsconfig.json").write_text("{}")
        (temp_repo / "Dockerfile").write_text("FROM node:16")

        result = registry._check_project_types(temp_repo)

        # Should detect multiple types
        assert len(result["detected_types"]) >= 2
        assert result["primary_type"] is not None

    def test_no_project_type(self, registry, temp_repo):
        """Test repository with no recognized project type."""
        (temp_repo / "README.md").write_text("# Test")

        result = registry._check_project_types(temp_repo)

        # Should either return empty or documentation type
        assert result["detected_types"] == [] or "documentation" in result["detected_types"]

    def test_jjb_special_case(self, registry, temp_repo):
        """Test special case for ci-management (JJB) repository."""
        # Rename temp_repo to ci-management
        ci_management_path = temp_repo.parent / "ci-management"
        temp_repo.rename(ci_management_path)

        result = registry._check_project_types(ci_management_path)

        assert result["detected_types"] == ["jjb"]
        assert result["primary_type"] == "jjb"

    def test_confidence_scoring(self, registry, temp_repo):
        """Test that confidence scoring works correctly."""
        # Create multiple Python files
        (temp_repo / "setup.py").write_text("from setuptools import setup")
        (temp_repo / "requirements.txt").write_text("requests==2.28.0")
        (temp_repo / "pyproject.toml").write_text("[tool.poetry]")

        result = registry._check_project_types(temp_repo)

        assert "Python" in result["detected_types"]
        # Should have details with confidence scores
        python_detail = next((d for d in result["details"] if d["type"] == "Python"), None)
        assert python_detail is not None
        assert python_detail["confidence"] >= 3  # At least 3 files

    def test_glob_pattern_matching(self, registry, temp_repo):
        """Test that glob patterns work correctly."""
        (temp_repo / "test1.py").write_text("print('test1')")
        (temp_repo / "test2.py").write_text("print('test2')")
        (temp_repo / "test3.py").write_text("print('test3')")

        result = registry._check_project_types(temp_repo)

        assert "Python" in result["detected_types"]
        # Should have found multiple .py files
        python_detail = next((d for d in result["details"] if d["type"] == "Python"), None)
        assert python_detail is not None
        assert len(python_detail["files"]) >= 3

    def test_case_sensitivity(self, registry, temp_repo):
        """Test that file detection is case-sensitive where needed."""
        # Test with Dockerfile (exact case)
        (temp_repo / "Dockerfile").write_text("FROM ubuntu")

        result = registry._check_project_types(temp_repo)

        assert "Dockerfile" in result["detected_types"]

    def test_primary_type_selection(self, registry, temp_repo):
        """Test that primary type is selected based on highest confidence."""
        # Create many Python files
        for i in range(5):
            (temp_repo / f"test{i}.py").write_text(f"print('test{i}')")

        # Create one JavaScript file
        (temp_repo / "index.js").write_text("console.log('test');")

        result = registry._check_project_types(temp_repo)

        # Python should be primary due to higher confidence
        assert result["primary_type"] == "Python"

    def test_details_structure(self, registry, temp_repo):
        """Test that the details structure is correct."""
        (temp_repo / "main.py").write_text("print('test')")

        result = registry._check_project_types(temp_repo)

        assert "details" in result
        assert isinstance(result["details"], list)

        if result["details"]:
            detail = result["details"][0]
            assert "type" in detail
            assert "files" in detail
            assert "confidence" in detail
            assert isinstance(detail["files"], list)
            assert isinstance(detail["confidence"], int)

    def test_empty_repository(self, registry, temp_repo):
        """Test detection on an empty repository."""
        result = registry._check_project_types(temp_repo)

        # Should handle empty repo gracefully
        assert isinstance(result, dict)
        assert "detected_types" in result
        assert "primary_type" in result
        assert "details" in result

    def test_typescript_jsx_tsx(self, registry, temp_repo):
        """Test TypeScript detection with JSX/TSX files."""
        (temp_repo / "Component.tsx").write_text("export const Component = () => <div />;")

        result = registry._check_project_types(temp_repo)

        assert "TypeScript" in result["detected_types"]

    def test_javascript_variants(self, registry, temp_repo):
        """Test JavaScript detection with various extensions."""
        (temp_repo / "module.mjs").write_text("export const test = 1;")
        (temp_repo / "common.cjs").write_text("module.exports = {};")

        result = registry._check_project_types(temp_repo)

        assert "JavaScript" in result["detected_types"]

    def test_docker_compose_variants(self, registry, temp_repo):
        """Test Dockerfile detection with docker-compose variants."""
        (temp_repo / "docker-compose.yaml").write_text("version: '3'")

        result = registry._check_project_types(temp_repo)

        assert "Dockerfile" in result["detected_types"]

    def test_detect_java_maven_combined(self, registry, temp_repo):
        """Test Java/Maven combined detection."""
        (temp_repo / "pom.xml").write_text("<project></project>")
        (temp_repo / "Main.java").write_text("public class Main { }")

        result = registry._check_project_types(temp_repo)

        assert "Java/Maven" in result["detected_types"]
        assert result["primary_type"] == "Java/Maven"
        # Should not have separate Java or Maven
        assert "Java" not in result["detected_types"]
        assert "Maven" not in result["detected_types"]

    def test_detect_java_gradle_combined(self, registry, temp_repo):
        """Test Java/Gradle combined detection."""
        (temp_repo / "build.gradle").write_text("plugins { id 'java' }")
        (temp_repo / "Main.java").write_text("public class Main { }")

        result = registry._check_project_types(temp_repo)

        assert "Java/Gradle" in result["detected_types"]
        assert result["primary_type"] == "Java/Gradle"
        # Should not have separate Java or Gradle
        assert "Java" not in result["detected_types"]
        assert "Gradle" not in result["detected_types"]

    def test_maven_without_java_files(self, registry, temp_repo):
        """Test Maven detection without Java files becomes Java/Maven."""
        (temp_repo / "pom.xml").write_text("<project></project>")

        result = registry._check_project_types(temp_repo)

        assert "Java/Maven" in result["detected_types"]
        assert result["primary_type"] == "Java/Maven"

    def test_gradle_without_java_files(self, registry, temp_repo):
        """Test Gradle detection without Java files becomes Java/Gradle."""
        (temp_repo / "settings.gradle").write_text("rootProject.name = 'test'")

        result = registry._check_project_types(temp_repo)

        # Should detect Java/Gradle (build.gradle files can be detected as Groovy too)
        assert "Java/Gradle" in result["detected_types"] or "Groovy" in result["detected_types"]
        # Primary should be one of these
        assert result["primary_type"] in ["Java/Gradle", "Groovy"]
