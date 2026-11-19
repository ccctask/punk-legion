"""One Windows job owns only this runner's Godot/editor descendants."""
import ctypes
from ctypes import wintypes as W
import json
import hashlib
from pathlib import Path
import subprocess
import time

K = ctypes.WinDLL('kernel32', use_last_error=True)
K.CreateJobObjectW.argtypes = [ctypes.c_void_p, W.LPCWSTR]
K.CreateJobObjectW.restype = W.HANDLE
K.SetInformationJobObject.argtypes = [W.HANDLE, ctypes.c_int, ctypes.c_void_p, W.DWORD]
K.QueryInformationJobObject.argtypes = [W.HANDLE, ctypes.c_int, ctypes.c_void_p, W.DWORD, ctypes.c_void_p]
K.AssignProcessToJobObject.argtypes = [W.HANDLE, W.HANDLE]
K.TerminateJobObject.argtypes = [W.HANDLE, W.UINT]
K.CloseHandle.argtypes = [W.HANDLE]
K.OpenProcess.argtypes = [W.DWORD, W.BOOL, W.DWORD]
K.OpenProcess.restype = W.HANDLE
K.GetProcessTimes.argtypes = [W.HANDLE] + [ctypes.POINTER(W.FILETIME)] * 4
K.QueryFullProcessImageNameW.argtypes = [W.HANDLE, W.DWORD, W.LPWSTR, ctypes.POINTER(W.DWORD)]
K.GetExitCodeProcess.argtypes = [W.HANDLE, ctypes.POINTER(W.DWORD)]

class Basic(ctypes.Structure):
    _fields_ = [('process_time', ctypes.c_int64), ('job_time', ctypes.c_int64), ('flags', W.DWORD),
        ('min_working', ctypes.c_size_t), ('max_working', ctypes.c_size_t), ('active', W.DWORD),
        ('affinity', ctypes.c_size_t), ('priority', W.DWORD), ('scheduling', W.DWORD)]
class IO(ctypes.Structure):
    _fields_ = [(name, ctypes.c_uint64) for name in ('read_ops','write_ops','other_ops','read_bytes','write_bytes','other_bytes')]
class Limits(ctypes.Structure):
    _fields_ = [('basic',Basic),('io',IO),('process_memory',ctypes.c_size_t),('job_memory',ctypes.c_size_t),
        ('peak_process',ctypes.c_size_t),('peak_job',ctypes.c_size_t)]

def identity(pid):
    handle = K.OpenProcess(0x1000, False, pid)
    if not handle: return None
    try:
        code=W.DWORD(); created=W.FILETIME(); exited=W.FILETIME(); kernel=W.FILETIME(); user=W.FILETIME()
        size=W.DWORD(32768); name=ctypes.create_unicode_buffer(size.value)
        if not K.GetExitCodeProcess(handle,ctypes.byref(code)) or code.value != 259: return None
        if not K.GetProcessTimes(handle,*[ctypes.byref(x) for x in (created,exited,kernel,user)]): return None
        if not K.QueryFullProcessImageNameW(handle,0,name,ctypes.byref(size)): return None
        return dict(pid=pid,created_100ns=(created.dwHighDateTime<<32)|created.dwLowDateTime,image=name.value)
    finally: K.CloseHandle(handle)

def job_pids(job):
    buf=ctypes.create_string_buffer(8 + 8*256)
    assert K.QueryInformationJobObject(job,3,buf,len(buf),None), ctypes.get_last_error()
    count=ctypes.c_uint32.from_buffer(buf,4).value
    assert count <= 256
    return [ctypes.c_size_t.from_buffer(buf,8+i*ctypes.sizeof(ctypes.c_size_t)).value for i in range(count)]

def owned_run(command, folder, env, timeout):
    folder.mkdir(parents=True,exist_ok=False)
    job=K.CreateJobObjectW(None,None); assert job
    limits=Limits(); limits.basic.flags=0x2000
    assert K.SetInformationJobObject(job,9,ctypes.byref(limits),ctypes.sizeof(limits))
    process=None; seen={}; started=time.monotonic()
    record=dict(command=list(map(str,command)),started_utc=time.time(),timeout_seconds=timeout,shared=False,seen=[])
    def save(): (folder/'process.json').write_text(json.dumps(record,indent=2),'utf8')
    timed_out=False;peak_processes=0;peak_godot_processes=0
    try:
        with (folder/'godot.log').open('wb') as output:
            process=subprocess.Popen(list(map(str,command)),env=env,stdout=output,stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW)
            if not K.AssignProcessToJobObject(job,W.HANDLE(process._handle)):
                process.kill(); process.wait(timeout=5)
                raise RuntimeError('Cannot assign owned Godot process to job')
            record['pid']=process.pid; save()
            while True:
                for pid in job_pids(job):
                    value=identity(pid)
                    if value: seen[(pid,value['created_100ns'])]=value
                record['seen']=list(seen.values()); save()
                current=[identity(pid) for pid in job_pids(job)]
                peak_processes=max(peak_processes,len([x for x in current if x]))
                peak_godot_processes=max(peak_godot_processes,len([x for x in current if x and 'godot' in x['image'].lower() and x['image'].lower().endswith('.exe')]))
                if process.poll() is not None: break
                if time.monotonic()-started >= timeout:
                    timed_out=True; break
                time.sleep(.05)
    finally:
        record['job_pids_before_cleanup']=job_pids(job)
        assert K.TerminateJobObject(job,124 if timed_out else 0)
        if process: process.wait(timeout=8)
        until=time.monotonic()+5
        while job_pids(job) and time.monotonic()<until: time.sleep(.05)
        record['job_pids_after_cleanup']=job_pids(job)
        K.CloseHandle(job)
        record.update(finished_utc=time.time(),elapsed_seconds=time.monotonic()-started,timed_out=timed_out,
            exit_code=process.returncode if process else None,seen=list(seen.values()),peak_owned_processes=peak_processes,peak_godot_executables=peak_godot_processes)
        record['same_instances_still_alive']=[x for x in seen.values() if identity(x['pid'])==x]
        record['process_image_sha256']={x['image']:hashlib.sha256(Path(x['image']).read_bytes()).hexdigest() for x in seen.values()}
        save()
    assert not record['job_pids_after_cleanup'] and not record['same_instances_still_alive']
    return record
