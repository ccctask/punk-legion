"""Pipe-only command execution using the project's existing Windows Job primitives."""
import ctypes
import importlib.util
from pathlib import Path
import subprocess
import time


def owned_capture(argv, *, input=None, timeout, cwd, **_):
    helper = Path(__file__).resolve().parent / 'process_owner.py'
    if not helper.is_file():
        helper = next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file()) / 'tests/godot/process_owner.py'
    spec = importlib.util.spec_from_file_location('operator_existing_owner', helper)
    owner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(owner)
    job = owner.K.CreateJobObjectW(None, None)
    if not job:
        raise RuntimeError('Cannot create operator command Job')
    process = None
    after = None
    try:
        limits = owner.Limits(); limits.basic.flags = 0x2000
        if not owner.K.SetInformationJobObject(job, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            raise RuntimeError('Cannot configure operator command Job')
        process = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   cwd=cwd, creationflags=subprocess.CREATE_NO_WINDOW)
        if not owner.K.AssignProcessToJobObject(job, owner.W.HANDLE(process._handle)):
            process.kill(); process.wait(timeout=5)
            raise RuntimeError('Cannot own operator command process')
        try:
            stdout, stderr = process.communicate(input.encode('utf-8') if input is not None else None, timeout=timeout)
        except subprocess.TimeoutExpired:
            owner.K.TerminateJobObject(job, 124)
            stdout, stderr = process.communicate(timeout=5)
            raise subprocess.TimeoutExpired(argv, timeout, output=stdout, stderr=stderr) from None
        result = subprocess.CompletedProcess(argv, process.returncode, stdout.decode('utf-8','replace'), stderr.decode('utf-8','replace'))
    finally:
        owner.K.TerminateJobObject(job, 0)
        if process is not None:
            process.wait(timeout=5)
        until = time.monotonic() + 5
        while owner.job_pids(job) and time.monotonic() < until:
            time.sleep(.05)
        after = owner.job_pids(job)
        owner.K.CloseHandle(job)
    if after:
        raise RuntimeError('Operator command Job still has descendants')
    result.ownership = {'job_pids_after_cleanup': after, 'pid': process.pid}
    return result
