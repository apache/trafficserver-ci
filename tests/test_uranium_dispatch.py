#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
"""Exercise Jenkins runner selection without building ATS or running Jenkins."""

from pathlib import Path
import os
import re
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
PIPELINES = (
    "jenkins/github/autest.pipeline",
    "jenkins/branch/autest.pipeline",
    "jenkins/branch/coverage.pipeline",
)


def shell_if(source: str, marker: str) -> str:
    """Extract one shell conditional, including nested conditionals.

    :param source: Pipeline or shell script containing the conditional.
    :param marker: Unique prefix identifying its first line.
    """
    lines = source.splitlines()
    start = next(index for index, line in enumerate(lines)
                 if line.strip().startswith(marker))
    depth = 0
    for end in range(start, len(lines)):
        line = lines[end].strip()
        if line.startswith("if "):
            depth += 1
        elif line == "fi":
            depth -= 1
            if not depth:
                return textwrap.dedent("\n".join(lines[start:end + 1]))
    raise AssertionError(f"Unterminated conditional: {marker}")


class RunnerSelectionTest(unittest.TestCase):
    """Cover CMake, Autotools, and pre-Uranium branches."""

    def setUp(self) -> None:
        """Create an isolated checkout-shaped directory."""
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.source = Path(self.temporary.name).resolve() / "src"
        self.tests = self.source / "tests"
        self.tests.mkdir(parents=True)

    def runner(self, directory: Path, status: int = 0) -> None:
        """Create a non-executable configured wrapper.

        :param directory: Directory containing the wrapper.
        :param status: Exit status the test suite should return.
        """
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "urtest.sh").write_text(
            'printf "runner=%s sandbox=%s args=%s\\n" "$PWD" "$ATS_URTEST_SANDBOX" "$*"\n'
            f"exit {status}\n")

    def run_shell(self, script: str,
                  directory: Path) -> subprocess.CompletedProcess[str]:
        """Execute an extracted pipeline fragment.

        :param script: Shell fragment under test.
        :param directory: Working directory corresponding to the Jenkins stage.
        """
        return subprocess.run(
            ["bash", "-c", script],
            cwd=directory,
            capture_output=True,
            text=True,
            env={
                **os.environ, "SANDBOX": "/tmp/test-sandbox",
                "pv_version": ""
            },
        )

    def test_pipeline_runner_selection(self) -> None:
        """Select configured Uranium wrappers and preserve legacy fallbacks."""
        for pipeline in PIPELINES:
            source = (ROOT / pipeline).read_text()
            start = source.index('urtest_directory=""')
            fragment = 'urtest_directory=""\n'
            fragment += shell_if(source[start:],
                                 "if [ -f ../build/tests/urtest.sh")
            selection = shell_if(source[start:],
                                 'if [ -n "${urtest_directory}"')
            # The unchanged AuTest block needs installed ATS and pipenv; replace
            # only that fallback with a marker while exercising real selection.
            selection = selection.split("\nelse\n",
                                        1)[0] + '\nelse\n  echo legacy\nfi\n'
            fragment += "\n" + selection
            for cmake, configured in ((False, False), (True, False),
                                      (False, True), (True, True)):
                with self.subTest(pipeline=pipeline,
                                  cmake=cmake,
                                  configured=configured):
                    cmake_dir = self.source / "cmake"
                    if cmake:
                        cmake_dir.mkdir(exist_ok=True)
                    elif cmake_dir.exists():
                        cmake_dir.rmdir()
                    for wrapper in self.source.rglob("urtest.sh"):
                        wrapper.unlink()
                    directory = self.source / "build/tests" if cmake else self.tests
                    if configured:
                        self.runner(directory)
                        if cmake:
                            self.runner(
                                self.tests)  # Source launcher must not win.
                    result = self.run_shell(
                        "set -e\ntest_failed=0\n" + fragment, self.tests)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    if configured:
                        self.assertIn(
                            f"runner={directory} sandbox=/tmp/sandbox",
                            result.stdout)
                        self.assertIn("--no-run-in-docker -v", result.stdout)
                        self.runner(directory, 7)
                        failed = self.run_shell(
                            "set -e\ntest_failed=0\n" + fragment +
                            '\nexit "$test_failed"\n', self.tests)
                        self.assertNotEqual(failed.returncode, 0)
                    else:
                        self.assertEqual(result.stdout.strip(), "legacy")
                        if cmake:
                            self.runner(self.tests)
                            result = self.run_shell(fragment, self.tests)
                            self.assertEqual(result.stdout.strip(), "legacy")

    def test_unconverted_test_guard(self) -> None:
        """Reject old tests only when the source tree has Uranium enabled."""
        paths = (*PIPELINES, "jenkins/bin/autest.sh")
        for path in paths:
            guard = shell_if((ROOT / path).read_text(),
                             "if [ -f tests/urtest.sh")
            with self.subTest(path=path):
                old_test = self.tests / "missed.test.py"
                old_test.write_text("# old AuTest\n")
                self.assertEqual(
                    self.run_shell(guard, self.source).returncode, 0)
                self.runner(self.tests)
                result = self.run_shell(guard, self.source)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Found unconverted AuTest files", result.stderr)
                self.assertIn("missed.test.py", result.stderr)
                old_test.unlink()
                self.assertEqual(
                    self.run_shell(guard, self.source).returncode, 0)
                (self.tests / "urtest.sh").unlink()

    def test_legacy_autotools_job(self) -> None:
        """The standalone job runs either Uranium or its original AuTest."""
        source = (ROOT / "jenkins/bin/autest.sh").read_text()
        invocation = shell_if(source[source.index('pv_version=""'):],
                              "if [ -f tests/urtest.sh")
        prefix = 'AUTEST=echo\nINSTALL=/tmp/ats\nSANDBOX=/tmp/test-sandbox\n'
        result = self.run_shell(prefix + invocation, self.source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-D ./tests/gold_tests", result.stdout)
        self.runner(self.tests)
        result = self.run_shell(prefix + invocation, self.source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("sandbox=/tmp/test-sandbox", result.stdout)
        self.runner(self.tests, 7)
        self.assertEqual(
            self.run_shell(prefix + invocation, self.source).returncode, 7)

    def test_pipeline_shell_syntax(self) -> None:
        """Keep embedded Jenkins shell scripts valid Bash."""
        for pipeline in PIPELINES:
            source = (ROOT / pipeline).read_text()
            for index, script in enumerate(
                    re.findall(r"sh '''(.*?)'''", source, re.DOTALL)):
                with self.subTest(pipeline=pipeline, script=index):
                    result = subprocess.run(["bash", "-n"],
                                            input=script,
                                            text=True,
                                            capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
