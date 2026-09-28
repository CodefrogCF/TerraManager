"""Exercise the production ARM64 server image with disposable SQLite storage.

Run on Linux after loading the image into Docker. No production credentials,
certificates, or databases are used. The administrator password stays in memory.
"""

import json
import os
import pty
import re
import secrets
import select
import subprocess
import sys
import tempfile
import termios
import time
import urllib.error
import urllib.request


def docker(*args, timeout=120):
    return subprocess.run(
        ("docker", *args), capture_output=True, text=True, timeout=timeout
    )


def container_options(data_dir):
    return (
        "--platform", "linux/arm64",
        "--group-add", str(os.getgid()),
        "--read-only",
        "--tmpfs", "/tmp:rw,mode=1777",
        "--mount", f"type=bind,source={data_dir},target=/data",
        "--env", "TM_DATABASE_PATH=/data/collection.sqlite",
        "--env", "TM_AUTH_DATABASE_PATH=/data/accounts.sqlite",
        "--env", "TM_PUBLIC_ORIGIN=http://127.0.0.1:8080",
        "--env", "TM_BIND_ADDRESS=0.0.0.0",
    )


def create_administrator(image, options, container_name):
    password = secrets.token_urlsafe(24)
    master, slave = pty.openpty()
    attributes = termios.tcgetattr(slave)
    attributes[3] &= ~termios.ECHO
    termios.tcsetattr(slave, termios.TCSANOW, attributes)
    process = None
    output = bytearray()
    try:
        process = subprocess.Popen(
            (
                "docker", "run", "--rm", "--interactive", "--tty",
                "--name", container_name, *options,
                "--entrypoint", "/opt/admin/bin/create_admin", image,
            ),
            stdin=slave, stdout=slave, stderr=slave,
        )
        os.close(slave)
        slave = -1

        def wait_for(marker, seconds=180):
            deadline = time.monotonic() + seconds
            while marker not in output:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise RuntimeError(f"Timed out waiting for administrator prompt {marker!r}")
                if not select.select([master], [], [], min(remaining, 1))[0]:
                    if process.poll() is not None:
                        raise RuntimeError("Administrator setup ended before completing")
                    continue
                try:
                    chunk = os.read(master, 4096)
                except OSError as error:
                    raise RuntimeError("Administrator setup closed its terminal") from error
                if not chunk:
                    raise RuntimeError("Administrator setup closed its terminal")
                output.extend(chunk)

        wait_for(b"Initial administrator username: ")
        os.write(master, b"ci-admin\n")
        wait_for(b"Password (at least 12 characters): ")
        os.write(master, password.encode("ascii") + b"\n")
        wait_for(b"Confirm password: ")
        os.write(master, password.encode("ascii") + b"\n")
        wait_for(b"Initial administrator created.")
        if process.wait(timeout=30) != 0:
            raise RuntimeError("Administrator setup returned an error")
    except Exception as error:
        # A terminal may echo input before the Dart CLI disables echo.
        transcript = bytes(output).replace(password.encode("ascii"), b"[redacted]")
        raise RuntimeError(
            f"Administrator setup failed: {transcript.decode(errors='replace')[-1000:]}"
        ) from error
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        os.close(master)
        if slave != -1:
            os.close(slave)


def check_health(container_name):
    port_result = docker("port", container_name, "8080/tcp")
    if port_result.returncode != 0:
        raise RuntimeError(f"Could not read server port: {port_result.stderr.strip()}")
    match = re.fullmatch(r"127\.0\.0\.1:(\d+)", port_result.stdout.strip())
    if match is None:
        raise RuntimeError(f"Unexpected server port mapping: {port_result.stdout.strip()}")
    url = f"http://127.0.0.1:{match.group(1)}/api/v1/health"
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=3) as response:
                if response.status == 200 and json.load(response) == {"status": "ok"}:
                    return
        except (OSError, ValueError, urllib.error.URLError):
            pass
        state = docker("inspect", "--format", "{{.State.Running}}", container_name)
        if state.returncode != 0 or state.stdout.strip() != "true":
            raise RuntimeError("Server exited before its health endpoint became ready")
        time.sleep(2)
    raise RuntimeError("Server health endpoint did not become ready")


def main(image):
    architecture = docker("image", "inspect", image, "--format", "{{.Os}}/{{.Architecture}}")
    if architecture.returncode != 0 or architecture.stdout.strip() != "linux/arm64":
        raise RuntimeError("The loaded server image is not linux/arm64")

    suffix = secrets.token_hex(6)
    names = (
        f"tm-ci-uninitialized-{suffix}",
        f"tm-ci-admin-{suffix}",
        f"tm-ci-server-{suffix}",
    )
    with tempfile.TemporaryDirectory(prefix="tm-server-smoke-") as data_dir:
        try:
            # The image runs as 10001:10001; only the runner's group can write here.
            os.chmod(data_dir, 0o770)
            options = container_options(data_dir)
            uninitialized = docker(
                "run", "--rm", "--name", names[0], *options, image, timeout=180
            )
            if uninitialized.returncode != 78 or "No accounts exist" not in uninitialized.stderr:
                raise RuntimeError("Server did not reject an uninitialized account store")
            print("Server refuses to start without an administrator.")

            create_administrator(image, options, names[1])
            print("Initial administrator setup succeeded.")

            started = docker(
                "run", "--detach", "--rm", "--name", names[2], *options,
                "--publish", "127.0.0.1::8080", image,
            )
            if started.returncode != 0:
                raise RuntimeError(f"Server did not start: {started.stderr.strip()}")
            check_health(names[2])
            print("Shared Care health endpoint returned HTTP 200 with status ok.")
        except Exception:
            logs = docker("logs", names[2])
            if logs.returncode == 0:
                print(logs.stdout + logs.stderr, file=sys.stderr)
            raise
        finally:
            for name in names:
                docker("rm", "--force", name, timeout=30)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 tool/ci/shared_server_smoke.py IMAGE")
    main(sys.argv[1])
