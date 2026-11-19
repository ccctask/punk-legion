"""Current-user DPAPI operator store. Never imports the signing builder/vault."""
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
from contextlib import contextmanager
from functools import wraps


class StoreFailure(RuntimeError):
    """Only explicitly non-secret stage/API/command diagnostics may be exposed."""
    def __init__(self, stage, **details):
        self.details = {'stage': stage, **details}
        super().__init__(json.dumps(self.details, ensure_ascii=True))


@contextmanager
def store_stage(name):
    try:
        yield
    except StoreFailure:
        raise
    except Exception as exc:
        # Do not stringify exceptions from decrypted bytes, JSON or credential processing.
        raise StoreFailure(name, type=type(exc).__name__, winerror=getattr(exc, 'winerror', None)) from None


def store_operation(name):
    def decorate(function):
        @wraps(function)
        def wrapped(*args, **kwargs):
            with store_stage(name):
                return function(*args, **kwargs)
        return wrapped
    return decorate


def safe_command(stage, argv):
    """Only whoami/icacls: their input/stdio never contains a token."""
    require(Path(argv[0]).name.lower() in ('whoami', 'icacls'), 'Unexpected store subprocess')
    try:
        return subprocess.run(argv, capture_output=True, text=True, errors='replace', check=True, timeout=10)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        stderr = exc.stderr or ''
        if isinstance(stderr, bytes):
            stderr = stderr.decode('utf-8', 'replace')
        raise StoreFailure(stage, type=type(exc).__name__, exit=getattr(exc, 'returncode', None),
                           stderr=stderr[:4096], stderr_truncated=len(stderr) > 4096) from None
    except OSError as exc:
        raise StoreFailure(stage, type=type(exc).__name__, winerror=exc.winerror) from None


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save_new(path, value):
    with Path(path).open('xb') as f:
        f.write((json.dumps(value, indent=2) + '\n').encode('utf-8'))


def dpapi(data, protect):
    require(os.name == 'nt', 'Windows current-user DPAPI required')
    class Blob(ctypes.Structure):
        _fields_ = [('size', wintypes.DWORD), ('ptr', ctypes.c_void_p)]
    buf = ctypes.create_string_buffer(data)
    src = Blob(len(data), ctypes.cast(buf, ctypes.c_void_p))
    dst = Blob()
    api = ctypes.WinDLL('crypt32', use_last_error=True)
    op = api.CryptProtectData if protect else api.CryptUnprotectData
    if not op(ctypes.byref(src), None, None, None, None, 1, ctypes.byref(dst)):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return ctypes.string_at(dst.ptr, dst.size)
    finally:
        ctypes.windll.kernel32.LocalFree(ctypes.c_void_p(dst.ptr))


def user_sid():
    result = safe_command('identity.whoami', ['whoami', '/user', '/fo', 'csv', '/nh'])
    matches = re.findall(r'S-1-5-[0-9-]+', result.stdout)
    require(len(matches) == 1, 'Cannot identify current Windows SID')
    return matches[0]


def read_acl(folder):
    """Read-only native owner/control/full ACE evidence; never reads store contents."""
    require(os.name == 'nt', 'Native Windows security descriptor required')
    adv = ctypes.WinDLL('advapi32', use_last_error=True)
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    pointer = ctypes.c_void_p
    adv.GetNamedSecurityInfoW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                         ctypes.POINTER(pointer), ctypes.POINTER(pointer),
                                         ctypes.POINTER(pointer), ctypes.POINTER(pointer), ctypes.POINTER(pointer)]
    adv.GetNamedSecurityInfoW.restype = wintypes.DWORD
    adv.GetSecurityDescriptorControl.argtypes = [pointer, ctypes.POINTER(wintypes.WORD), ctypes.POINTER(wintypes.DWORD)]
    adv.GetSecurityDescriptorControl.restype = wintypes.BOOL
    adv.GetAclInformation.argtypes = [pointer, pointer, wintypes.DWORD, ctypes.c_int]
    adv.GetAclInformation.restype = wintypes.BOOL
    adv.GetAce.argtypes = [pointer, wintypes.DWORD, ctypes.POINTER(pointer)]
    adv.GetAce.restype = wintypes.BOOL
    adv.IsValidSid.argtypes = [pointer]
    adv.IsValidSid.restype = wintypes.BOOL
    adv.ConvertSidToStringSidW.argtypes = [pointer, ctypes.POINTER(pointer)]
    adv.ConvertSidToStringSidW.restype = wintypes.BOOL
    kernel.LocalFree.argtypes = [pointer]
    kernel.LocalFree.restype = pointer

    def checked(ok, api):
        if not ok:
            raise StoreFailure('acl.read.' + api, winerror=ctypes.get_last_error())

    def sid_text(sid):
        checked(adv.IsValidSid(sid), 'IsValidSid')
        text = pointer()
        checked(adv.ConvertSidToStringSidW(sid, ctypes.byref(text)), 'ConvertSidToStringSidW')
        try:
            return ctypes.wstring_at(text)
        finally:
            kernel.LocalFree(text)

    class AclSize(ctypes.Structure):
        _fields_ = [('count', wintypes.DWORD), ('in_use', wintypes.DWORD), ('free', wintypes.DWORD)]

    class AceHeader(ctypes.Structure):
        _fields_ = [('type', wintypes.BYTE), ('flags', wintypes.BYTE), ('size', wintypes.WORD)]

    owner, dacl, descriptor = pointer(), pointer(), pointer()
    # SE_FILE_OBJECT=1; OWNER_SECURITY_INFORMATION|DACL_SECURITY_INFORMATION=5.
    error = adv.GetNamedSecurityInfoW(str(Path(folder).resolve()), 1, 5, ctypes.byref(owner), None,
                                     ctypes.byref(dacl), None, ctypes.byref(descriptor))
    if error:
        if descriptor:
            kernel.LocalFree(descriptor)
        raise StoreFailure('acl.read.GetNamedSecurityInfoW', winerror=error)
    try:
        control, revision = wintypes.WORD(), wintypes.DWORD()
        checked(adv.GetSecurityDescriptorControl(descriptor, ctypes.byref(control), ctypes.byref(revision)),
                'GetSecurityDescriptorControl')
        value = {'owner': sid_text(owner), 'control': control.value, 'revision': revision.value,
                 'protected': bool(control.value & 0x1000), 'dacl_present': bool(control.value & 0x4),
                 'null_dacl': not bool(dacl), 'rows': []}
        if dacl:
            size = AclSize()
            checked(adv.GetAclInformation(dacl, ctypes.byref(size), ctypes.sizeof(size), 2), 'GetAclInformation')
            value['acl_bytes_in_use'] = size.in_use
            for index in range(size.count):
                ace = pointer()
                checked(adv.GetAce(dacl, index, ctypes.byref(ace)), 'GetAce')
                header = AceHeader.from_address(ace.value)
                row = {'index': index, 'ace_type': header.type, 'flags': header.flags, 'size': header.size,
                       'raw_hex': ctypes.string_at(ace, header.size).hex()}
                # Only simple ACCESS_ALLOWED_ACE is admissible; other ACEs are recorded/rejected,
                # never interpreted using the wrong SID offset.
                if header.type == 0 and header.size >= 16:
                    row.update(type='Allow', rights=wintypes.DWORD.from_address(ace.value + 4).value,
                               sid=sid_text(pointer(ace.value + 8)))
                else:
                    row.update(type='Unsupported', rights=None, sid=None)
                value['rows'].append(row)
        return value
    finally:
        kernel.LocalFree(descriptor)


def check_acl(folder, sid):
    value = read_acl(folder)
    if not value['protected'] or value['owner'] != sid:
        raise StoreFailure('acl.verify', rule='owner/protected', acl=value)
    rows = value['rows']
    if not (value['dacl_present'] and not value['null_dacl']
            and {x['sid'] for x in rows} == {sid, 'S-1-5-18'}
            and all(x['type'] == 'Allow' and x['rights'] == 2032127 and x['flags'] == 3 for x in rows)):
        raise StoreFailure('acl.verify', rule='present-nonnull/only-user-system/allow/fullcontrol/flags3', acl=value)
    return value


def configure_new_directory_acl(folder, sid):
    """Only called immediately after this invocation creates its exclusive new directory."""
    safe_command('acl.setowner', ['icacls', str(folder), '/setowner', '*' + sid])
    safe_command('acl.grant', ['icacls', str(folder), '/inheritance:r', '/grant:r',
                              f'*{sid}:(OI)(CI)F', '*S-1-5-18:(OI)(CI)F'])


@store_operation('initialize')
def initialize(folder, scope):
    require(Path(folder).is_absolute(), 'Operator store path must be absolute')
    folder = Path(folder).resolve()
    require(folder.is_absolute() and not folder.exists(), 'Explicit new operator store required; refuse overwrite')
    require('operator' in folder.name.lower() and 'signing' not in [x.lower() for x in folder.parts],
            'Use dedicated operator-named directory outside signing paths')
    sid = user_sid()
    folder.mkdir(parents=True, exist_ok=False)
    configure_new_directory_acl(folder, sid)
    with store_stage('initialize.acl.verify'):
        check_acl(folder, sid)
    metadata = {'format': 1, 'scope': scope, 'sid': sid, 'roles': {}}
    for role in ('viewer', 'compensator'):
        with store_stage('initialize.' + role + '.seal'):
            token = secrets.token_urlsafe(48)
            sealed = dpapi(token.encode('ascii'), True)
        with (folder / (role + '.dpapi')).open('xb') as f:
            f.write(sealed)
        policy = {role: {'role': role, 'sha256': sha(token.encode('ascii'))}}
        save_new(folder / (role + '.policy.json'), policy)
        metadata['roles'][role] = {'sealed_sha256': sha(sealed),
                                  'policy_sha256': sha((folder / (role + '.policy.json')).read_bytes())}
    save_new(folder / 'metadata.json', metadata)
    # Incomplete stores are deliberately retained on failure; never silently reinitialize.
    load(folder, 'viewer', scope)
    load(folder, 'compensator', scope)
    return metadata


@store_operation('load')
def load(folder, role, scope):
    folder = Path(folder).resolve()
    sid = user_sid()
    with store_stage('load.acl.verify'):
        check_acl(folder, sid)
    with store_stage('load.metadata'):
        metadata = json.loads((folder / 'metadata.json').read_text('utf-8'))
    require(metadata['format'] == 1 and metadata['scope'] == scope and metadata['sid'] == sid,
            'Operator store scope/user mismatch')
    entry = metadata['roles'][role]
    sealed = (folder / (role + '.dpapi')).read_bytes()
    policy_bytes = (folder / (role + '.policy.json')).read_bytes()
    require(sha(sealed) == entry['sealed_sha256'] and sha(policy_bytes) == entry['policy_sha256'],
            'Operator store file identity mismatch')
    policy = json.loads(policy_bytes)
    with store_stage('load.' + role + '.unseal'):
        token = dpapi(sealed, False).decode('ascii')
    require(re.fullmatch(r'[A-Za-z0-9_-]{64}', token) is not None, 'Invalid decrypted operator token format')
    require(policy == {role: {'role': role, 'sha256': sha(token.encode('ascii'))}},
            'Policy must contain exactly the selected role and matching digest')
    return token, policy_bytes
