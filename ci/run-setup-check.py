#!/usr/bin/env python3
"""Run check-setup-mds.sh the way a student does, and answer its prompts.

Both prompts in that script are guarded by `[ -t 0 ]` and default to no without a
terminal, which is the point: a script that is piped or scheduled must never record a
student's environment. So exercising the student path in CI needs a real terminal, and
feeding one from a pipe misaligns the answers -- verified: the answers arrive before the
prompts and land on the wrong questions.

This attaches a pseudo-terminal and answers each prompt only after seeing it.

    python3 ci/run-setup-check.py /path/to/check-setup-mds.sh

Everything the script prints is passed through, so the job log shows exactly what a
student would see. The exit status is the script's own.
"""
import os, pty, re, select, sys

# (what to wait for, what to answer, why)
ANSWERS = [
    # Either form of the first question. A runner with no ~/mds-setup-check is asked
    # to create it; one that already has the folder -- a warm or self-hosted runner --
    # is asked whether to replace it instead, and the two are alternatives rather than
    # both appearing. Matching only the first would stall here until the timeout.
    (re.compile(r"Set up the MDS check project now\?|and download a fresh copy\?"), b"y\n",
     "yes: the point of the run is to exercise the checks that need the project"),
    (re.compile(r"Include environment variables in the log\?"), b"n\n",
     "no: the default, and the answer students are told to give"),
]


def main() -> int:
    script = sys.argv[1]
    pid, fd = pty.fork()
    if pid == 0:                                   # child: becomes the script
        os.execvp("bash", ["bash", script])

    pending, seen = list(ANSWERS), ""
    while True:
        if not select.select([fd], [], [], 1200)[0]:
            print("\n[driver] no output for 20 minutes, giving up", flush=True)
            os.kill(pid, 9)
            return 1
        try:
            chunk = os.read(fd, 4096)
        except OSError:                            # the pty closes when the script exits
            break
        if not chunk:
            break
        sys.stdout.write(chunk.decode("utf-8", "replace"))
        sys.stdout.flush()
        # Only the tail is kept: a prompt is one line, and the log is megabytes.
        seen = (seen + chunk.decode("utf-8", "replace"))[-4000:]
        if pending and pending[0][0].search(seen):
            pattern, reply, why = pending.pop(0)
            print(f"\n[driver] answering {reply!r} -- {why}", flush=True)
            os.write(fd, reply)
            seen = ""

    status = os.waitpid(pid, 0)[1]
    if pending:
        print(f"[driver] {len(pending)} prompt(s) never appeared: "
              + ", ".join(p.pattern for p, _, _ in pending), flush=True)
        return 1
    return os.waitstatus_to_exitcode(status)


if __name__ == "__main__":
    sys.exit(main())
