#!/usr/bin/env python3
"""Local, internal-only TestFlight delivery using Apple's public API."""
import argparse
import base64
import fcntl
import json
import math
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

ROOT = Path(__file__).resolve().parents[1]
API_ORIGIN = 'https://api.appstoreconnect.apple.com'
APP_ID = '6811887105'
BUNDLE_ID = 'app.pentaphor.personal'
TEAM_ID = 'NX53XT8XMU'
DEFAULT_CONFIG = Path.home()/'.config/pentaphor/app-store-connect.json'
DEFAULT_SIMULATOR = 'B3147374-5BC7-48E0-952D-C3E55BE423C3'

class DeliveryError(RuntimeError): pass

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise DeliveryError('Unexpected API redirect; credentials were not forwarded.')

def make_token(key, key_id, issuer_id, now=None):
    now = int(time.time() if now is None else now)
    encode = lambda value: base64.urlsafe_b64encode(value).rstrip(b'=')
    header = {'alg':'ES256', 'kid':key_id, 'typ':'JWT'}
    claims = {'iss':issuer_id, 'iat':now, 'exp':now+600, 'aud':'appstoreconnect-v1'}
    signing = b'.'.join(encode(json.dumps(v, separators=(',', ':')).encode()) for v in [header, claims])
    r, s = utils.decode_dss_signature(key.sign(signing, ec.ECDSA(hashes.SHA256())))
    return (signing+b'.'+encode(r.to_bytes(32, 'big')+s.to_bytes(32, 'big'))).decode()

def private_key(data):
    try: key = serialization.load_pem_private_key(data, password=None)
    except (ValueError, TypeError): raise DeliveryError('Cannot read the .p8 private key.') from None
    if not isinstance(key, ec.EllipticCurvePrivateKey) or not isinstance(key.curve, ec.SECP256R1):
        raise DeliveryError('An App Store Connect ES256 team key is required.')
    return key

def outside_repo(path):
    path = Path(path).expanduser().resolve()
    if path.is_relative_to(ROOT): raise DeliveryError('Store credentials outside this repository.')
    return path

def configure(source, key_id, issuer_id, config=DEFAULT_CONFIG):
    config = outside_repo(config)
    if not key_id.strip() or not issuer_id.strip(): raise DeliveryError('Key ID and Issuer ID are required.')
    if config.exists(): raise DeliveryError('Configuration exists; refusing to replace credentials.')
    data = Path(source).expanduser().read_bytes()
    private_key(data)
    config.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    config.parent.chmod(0o700)
    key_path = config.parent/'AuthKey.p8'
    try:
        fd = os.open(key_path, os.O_CREAT|os.O_EXCL|os.O_WRONLY, 0o600)
        with os.fdopen(fd, 'wb') as stream: stream.write(data)
        fd = os.open(config, os.O_CREAT|os.O_EXCL|os.O_WRONLY, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump({'key_file':str(key_path), 'key_id':key_id.strip(), 'issuer_id':issuer_id.strip()}, stream)
    except FileExistsError: raise DeliveryError('Private configuration already exists; no file was replaced.') from None
    print('API credentials stored outside the repository. Private key contents are never logged.')

def load_config(path):
    path = outside_repo(path)
    if not path.exists(): raise DeliveryError('API key not configured. Run the configure command once; see docs/testflight-internal.md.')
    config = json.loads(path.read_text())
    key_path = outside_repo(config['key_file'])
    for private in [path, key_path]:
        if private.stat().st_mode & 0o077: raise DeliveryError('Credential files must have mode 600.')
    key = private_key(key_path.read_bytes())
    return config, AppleAPI(lambda: make_token(key, config['key_id'], config['issuer_id']))

class AppleAPI:
    def __init__(self, token):
        self.token = token
        self.opener = urllib.request.build_opener(NoRedirect())
    def get(self, path, params=None):
        if path.startswith('/v1/'): url = API_ORIGIN+path
        else: url = path
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != 'https' or parsed.netloc != 'api.appstoreconnect.apple.com' or not parsed.path.startswith('/v1/'):
            raise DeliveryError('Refusing to send API credentials outside the Apple API origin.')
        if params: url += ('&' if parsed.query else '?')+urllib.parse.urlencode(params)
        for attempt in range(4):
            request = urllib.request.Request(url, headers={'Authorization':'Bearer '+self.token(), 'Accept':'application/json'})
            try:
                with self.opener.open(request, timeout=30) as response: return json.load(response)
            except urllib.error.HTTPError as error:
                if error.code not in [429, 500, 502, 503, 504] or attempt == 3:
                    raise DeliveryError(f'Apple API HTTP {error.code}. Check key access for 401/403; no token was logged.') from None
            except (urllib.error.URLError, TimeoutError):
                if attempt == 3: raise DeliveryError('Apple API network request failed after bounded retries.') from None
            time.sleep(min(2**(attempt+1), 30))

def collection(api, path, params=None):
    seen = set()
    while path:
        if path in seen: raise DeliveryError('Apple returned a repeated pagination link.')
        seen.add(path)
        result = api.get(path, params)
        yield from result['data']
        path = result.get('links', {}).get('next')
        params = None

def personal_group(api):
    groups = list(collection(api, '/v1/betaGroups', {'filter[app]':APP_ID, 'filter[name]':'Personal', 'limit':200}))
    if len(groups) != 1: raise DeliveryError('Expected exactly one Personal group for PENTAPHOR.')
    group = groups[0]
    attrs = group['attributes']
    if attrs.get('name') != 'Personal' or not attrs.get('isInternalGroup') or not attrs.get('hasAccessToAllBuilds'):
        raise DeliveryError('Personal must be an internal group with automatic distribution enabled.')
    return group['id']

def build_filters(version, build):
    return {'filter[app]':APP_ID, 'filter[version]':str(build), 'filter[preReleaseVersion.version]':version,
            'filter[preReleaseVersion.platform]':'IOS', 'limit':200}

def delivery_status(api, version, build, group):
    params = build_filters(version, build)
    result = api.get('/v1/builds', dict(params, include='buildBetaDetail,preReleaseVersion'))
    if not result['data']: return 'awaiting-upload-processing'
    if len(result['data']) != 1: raise DeliveryError('Ambiguous build lookup; refusing to report delivery.')
    record = result['data'][0]; attrs = record['attributes']
    if attrs.get('version') != str(build): raise DeliveryError('Build number does not match.')
    state = attrs.get('processingState')
    if state in ['FAILED', 'INVALID'] or attrs.get('expired'): raise DeliveryError(f'Apple rejected or expired build {build}: {state}.')
    if state != 'VALID': return 'processing'
    if attrs.get('buildAudienceType') != 'INTERNAL_ONLY': raise DeliveryError('Build is not internal-only.')
    included = {(item['type'],item['id']):item['attributes'] for item in result.get('included', [])}
    relations = record.get('relationships', {})
    release_id = relations.get('preReleaseVersion', {}).get('data', {}).get('id')
    release = included.get(('preReleaseVersions',release_id), {})
    if release.get('version') != version or release.get('platform') != 'IOS': raise DeliveryError('Marketing version or platform does not match.')
    detail_id = relations.get('buildBetaDetail', {}).get('data', {}).get('id')
    internal = included.get(('buildBetaDetails',detail_id), {}).get('internalBuildState')
    if internal in ['PROCESSING_EXCEPTION','MISSING_EXPORT_COMPLIANCE','EXPIRED']:
        raise DeliveryError(f'Internal testing requires attention: {internal}.')
    if internal != 'IN_BETA_TESTING': return 'awaiting-internal-testing'
    members = api.get('/v1/builds', dict(params, **{'filter[id]':record['id'], 'filter[betaGroups]':group}))
    return 'ready' if any(row['id'] == record['id'] for row in members['data']) else 'awaiting-group-distribution'

def wait_ready(check, timeout=1800, interval=30, sleep=time.sleep):
    if timeout <= 0 or not 0 < interval <= 60: raise DeliveryError('Use a positive timeout and a poll interval of at most 60 seconds.')
    deadline = time.monotonic()+timeout
    previous = None
    for attempt in range(math.ceil(timeout/interval)+1):
        state = check()
        if state != previous: print('TestFlight: '+state, flush=True); previous = state
        if state == 'ready': return state
        if time.monotonic() >= deadline or attempt == math.ceil(timeout/interval): break
        sleep(min(interval, max(0, deadline-time.monotonic())))
    raise DeliveryError('Apple processing/distribution is still pending. Resume with status --wait; do not re-upload this build.')

def next_build(api, version, current):
    values = [int(current)]
    for record in collection(api, '/v1/builds', {'filter[app]':APP_ID, 'filter[preReleaseVersion.version]':version, 'filter[preReleaseVersion.platform]':'IOS', 'limit':200}):
        value = record['attributes']['version']
        if not value.isdecimal(): raise DeliveryError('Non-numeric server build number requires manual numbering.')
        values.append(int(value))
    return max(values)+1

def auth_args(config):
    return ['-allowProvisioningUpdates', '-authenticationKeyPath', config['key_file'],
            '-authenticationKeyID', config['key_id'], '-authenticationKeyIssuerID', config['issuer_id']]

def export_options():
    options = plistlib.loads((ROOT/'Configuration/TestFlightExport.plist').read_bytes())
    if options.get('teamID') != TEAM_ID or options.get('destination') != 'upload' or options.get('testFlightInternalTestingOnly') is not True:
        raise DeliveryError('Export configuration must retain the existing team and internal-only upload.')
    options['manageAppVersionAndBuildNumber'] = False
    return options

def run_logged(command, log):
    print('Running '+Path(command[0]).name+'; log: '+str(log), flush=True)
    with Path(log).open('w') as stream:
        if Path(log).suffix == '.json':
            with Path(log).with_suffix('.stderr.log').open('w') as errors:
                result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=errors)
        else:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode: raise DeliveryError(f'{Path(command[0]).name} failed ({result.returncode}); see {log}. No later delivery step ran.')

def run_tests(output, run, simulator):
    run([sys.executable,'-m','unittest','discover','-s','scripts/tests','-v'],output/'automation-tests.log')
    run(['swift','test','--package-path','Packages/PentaphorCore','-c','release'],output/'core-tests.log')
    run(['xcodebuild','test','-project','Pentaphor.xcodeproj','-scheme','Pentaphor','-destination',f'platform=iOS Simulator,id={simulator}',
         '-derivedDataPath',str(output/'UITestDerivedData'),'-resultBundlePath',str(output/'UI.xcresult'),'CODE_SIGNING_ALLOWED=NO'],output/'ui-tests.log')

def deploy(config, api, output, simulator, run=run_logged):
    group = personal_group(api)
    app = api.get('/v1/apps/'+APP_ID)['data']
    if app['attributes'].get('bundleId') != BUNDLE_ID: raise DeliveryError('App identity mismatch.')
    settings_file = output/'build-settings.json'
    run(['xcodebuild','-showBuildSettings','-json','-project','Pentaphor.xcodeproj','-scheme','Pentaphor','-configuration','Release','-destination','generic/platform=iOS'], settings_file)
    settings = next(item['buildSettings'] for item in json.loads(settings_file.read_text()) if item['target']=='Pentaphor')
    if settings['PRODUCT_BUNDLE_IDENTIFIER'] != BUNDLE_ID or settings['DEVELOPMENT_TEAM'] != TEAM_ID: raise DeliveryError('Project signing identity changed.')
    version = settings['MARKETING_VERSION']; build = next_build(api,version,settings['CURRENT_PROJECT_VERSION'])
    # Record the chosen build before side effects so interrupted uploads can be checked without retrying them.
    (output/'delivery.json').write_text(json.dumps({'version':version,'build':str(build),'group':group}))
    print(f'Preparing PENTAPHOR {version} ({build})', flush=True)
    options = export_options()
    run_tests(output, run, simulator)
    archive = output/'Pentaphor.xcarchive'
    run(['xcodebuild','archive','-project','Pentaphor.xcodeproj','-scheme','Pentaphor','-configuration','Release','-destination','generic/platform=iOS',
         '-archivePath',str(archive),'-derivedDataPath',str(output/'ReleaseDerivedData'),f'CURRENT_PROJECT_VERSION={build}']+auth_args(config),output/'archive.log')
    info = plistlib.loads((archive/'Products/Applications/Pentaphor.app/Info.plist').read_bytes())
    if (info.get('CFBundleIdentifier'),info.get('CFBundleShortVersionString'),info.get('CFBundleVersion'),info.get('UIDeviceFamily')) != (BUNDLE_ID,version,str(build),[1]):
        raise DeliveryError('Archived app identity/version/device family did not match.')
    export = output/'ExportOptions.plist'; export.write_bytes(plistlib.dumps(options))
    run(['xcodebuild','-exportArchive','-archivePath',str(archive),'-exportOptionsPlist',str(export),'-exportPath',str(output/'Upload')]+auth_args(config),output/'upload.log')
    wait_ready(lambda: delivery_status(api,version,str(build),group))
    print(f'READY: PENTAPHOR {version} ({build}) is in Personal internal testing.', flush=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=DEFAULT_CONFIG)
    commands = parser.add_subparsers(dest='command',required=True)
    setup = commands.add_parser('configure')
    setup.add_argument('--key-file',type=Path,required=True); setup.add_argument('--key-id',required=True); setup.add_argument('--issuer-id',required=True)
    status = commands.add_parser('status'); status.add_argument('--version',required=True); status.add_argument('--build',required=True)
    status.add_argument('--wait',action='store_true'); status.add_argument('--timeout',type=int,default=1800)
    release = commands.add_parser('deploy'); release.add_argument('--simulator',default=DEFAULT_SIMULATOR)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        if args.command == 'configure':
            configure(args.key_file,args.key_id,args.issuer_id,args.config); return 0
        config, api = load_config(args.config)
        if args.command == 'status':
            group = personal_group(api)
            check = lambda: delivery_status(api,args.version,args.build,group)
            if args.wait: wait_ready(check,timeout=args.timeout)
            else:
                state = check(); print(state)
                return 0 if state == 'ready' else 2
        else:
            with (args.config.parent/'delivery.lock').open('a') as lock:
                try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                except BlockingIOError: raise DeliveryError('Another local delivery is running.') from None
                base = Path.home()/'Library/Developer/PentaphorDeliveries'; base.mkdir(parents=True,exist_ok=True)
                output = Path(tempfile.mkdtemp(prefix=time.strftime('%Y%m%d-%H%M%S-'),dir=base))
                deploy(config,api,output,args.simulator)
        return 0
    except (DeliveryError, OSError, ValueError, KeyError, StopIteration) as error:
        if isinstance(error, DeliveryError): print(str(error),file=sys.stderr)
        else: print('Local configuration or Apple response could not be read; no delivery success was recorded.',file=sys.stderr)
        return 1

if __name__=='__main__': sys.exit(main())
