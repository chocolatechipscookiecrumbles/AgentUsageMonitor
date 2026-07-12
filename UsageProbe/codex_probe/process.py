from __future__ import annotations

import subprocess
import json
import selectors
import time
from dataclasses import dataclass


class UnsafeCodexCommand(ValueError):
    """Raised before a command outside the read-only allowlist can execute."""


class CodexCommandError(RuntimeError):
    """A sanitized Codex subprocess failure."""


@dataclass(frozen=True)
class CommandResult:
    exit_code: int
    stdout: str
    stderr: str


class SafeCodexRunner:
    _ALLOWED_ARGUMENTS = {
        ("--version",),
        ("login", "status"),
        ("doctor", "--json"),
        ("app-server", "--listen", "stdio://"),
    }

    def run(
        self,
        executable: str,
        arguments: tuple[str, ...],
        stdin: str | None,
        timeout: float,
    ) -> CommandResult:
        if arguments not in self._ALLOWED_ARGUMENTS:
            raise UnsafeCodexCommand(f"Codex arguments are not allowlisted: {arguments!r}")
        if arguments == ("app-server", "--listen", "stdio://"):
            return self._run_app_server(executable, arguments, stdin, timeout)
        try:
            completed = subprocess.run(
                (executable, *arguments),
                input=stdin,
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
            )
        except FileNotFoundError as error:
            raise CodexCommandError("Codex executable was not found") from error
        except subprocess.TimeoutExpired as error:
            raise CodexCommandError("Codex command timed out") from error
        return CommandResult(completed.returncode, completed.stdout, completed.stderr)

    def _run_app_server(
        self,
        executable: str,
        arguments: tuple[str, ...],
        stdin: str | None,
        timeout: float,
    ) -> CommandResult:
        request_lines = (stdin or "").splitlines()
        if not request_lines:
            raise CodexCommandError("App-server input is empty")
        try:
            requests = [json.loads(line) for line in request_lines]
            request_ids = {item["id"] for item in requests if isinstance(item, dict) and "id" in item}
            initialize_id = requests[0]["id"]
        except (json.JSONDecodeError, KeyError, TypeError) as error:
            raise CodexCommandError("App-server input is invalid") from error

        try:
            process = subprocess.Popen(
                (executable, *arguments),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
            )
        except FileNotFoundError as error:
            raise CodexCommandError("Codex executable was not found") from error

        stdout_lines: list[str] = []
        stderr_lines: list[str] = []
        received_ids: set[object] = set()
        selector = selectors.DefaultSelector()
        try:
            assert process.stdin is not None
            assert process.stdout is not None
            assert process.stderr is not None
            selector.register(process.stdout, selectors.EVENT_READ, stdout_lines)
            selector.register(process.stderr, selectors.EVENT_READ, stderr_lines)

            process.stdin.write(request_lines[0] + "\n")
            process.stdin.flush()
            deadline = time.monotonic() + timeout
            sent_reads = False

            while request_ids - received_ids:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise CodexCommandError("Codex command timed out")
                events = selector.select(remaining)
                if not events and process.poll() is not None:
                    break
                for key, _ in events:
                    line = key.fileobj.readline()
                    if line == "":
                        selector.unregister(key.fileobj)
                        continue
                    key.data.append(line.rstrip("\n"))
                    if key.fileobj is not process.stdout:
                        continue
                    try:
                        message = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if isinstance(message, dict) and message.get("id") in request_ids:
                        received_ids.add(message["id"])
                if initialize_id in received_ids and not sent_reads:
                    for line in request_lines[1:]:
                        process.stdin.write(line + "\n")
                    process.stdin.flush()
                    sent_reads = True
                if process.poll() is not None and request_ids - received_ids:
                    break
        finally:
            selector.close()
            if process.stdin is not None:
                process.stdin.close()
            if process.poll() is None:
                process.terminate()
            try:
                exit_code = process.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                process.kill()
                exit_code = process.wait()
            if process.stdout is not None:
                process.stdout.close()
            if process.stderr is not None:
                process.stderr.close()

        if request_ids - received_ids:
            return CommandResult(exit_code or 1, "\n".join(stdout_lines), "\n".join(stderr_lines))
        return CommandResult(0, "\n".join(stdout_lines), "\n".join(stderr_lines))
