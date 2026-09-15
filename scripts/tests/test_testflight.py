import base64
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import testflight as tf
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils


def build_response(state='VALID', internal='IN_BETA_TESTING', audience='INTERNAL_ONLY', expired=False):
    return {'data': [{'id': 'build-2', 'attributes': {'version': '2', 'processingState': state, 'expired': expired, 'buildAudienceType': audience},
                     'relationships': {'buildBetaDetail': {'data': {'id': 'detail'}}, 'preReleaseVersion': {'data': {'id': 'release'}}}}],
            'included': [{'type': 'buildBetaDetails', 'id': 'detail', 'attributes': {'internalBuildState': internal}},
                         {'type': 'preReleaseVersions', 'id': 'release', 'attributes': {'version': '1.0', 'platform': 'IOS'}}]}

class APIStub:
    def __init__(self, responses): self.responses = list(responses); self.urls = []
    def get(self, path, params=None):
        self.urls.append((path, params))
        return self.responses.pop(0)

class DeliveryTests(unittest.TestCase):
    def test_processing_is_not_delivery_success(self):
        self.assertEqual(tf.delivery_status(APIStub([build_response(state='PROCESSING')]), '1.0', '2', 'group'), 'processing')
    def test_absent_build_is_pending_not_success(self):
        self.assertEqual(tf.delivery_status(APIStub([{'data': []}]), '1.0', '2', 'group'), 'awaiting-upload-processing')
    def test_valid_build_must_be_in_requested_internal_group(self):
        api = APIStub([build_response(), {'data': []}])
        self.assertEqual(tf.delivery_status(api, '1.0', '2', 'group'), 'awaiting-group-distribution')
        api = APIStub([build_response(), {'data': [{'id': 'build-2'}]}])
        self.assertEqual(tf.delivery_status(api, '1.0', '2', 'group'), 'ready')
        self.assertEqual(api.urls[1][1]['filter[betaGroups]'], 'group')
        self.assertEqual(api.urls[0][1]['filter[app]'], tf.APP_ID)
        self.assertEqual(api.urls[0][1]['filter[preReleaseVersion.version]'], '1.0')
    def test_failed_expired_compliance_and_public_audience_stop(self):
        for response in [build_response(state='FAILED'), build_response(state='INVALID'), build_response(expired=True),
                         build_response(audience='APP_STORE_ELIGIBLE'), build_response(internal='MISSING_EXPORT_COMPLIANCE'),
                         build_response(internal='PROCESSING_EXCEPTION')]:
            with self.subTest(response=response), self.assertRaises(tf.DeliveryError):
                tf.delivery_status(APIStub([response]), '1.0', '2', 'group')
    def test_wrong_build_or_marketing_version_never_matches(self):
        for response in [build_response(), build_response()]:
            response['data'][0]['attributes']['version'] = '99'
            with self.assertRaises(tf.DeliveryError): tf.delivery_status(APIStub([response]), '1.0', '2', 'group')
        response = build_response()
        response['included'][1]['attributes']['version'] = '2.0'
        with self.assertRaises(tf.DeliveryError): tf.delivery_status(APIStub([response]), '1.0', '2', 'group')
    def test_wait_polls_until_ready_and_times_out_without_upload(self):
        states = iter(['processing', 'awaiting-group-distribution', 'ready'])
        waits = []
        self.assertEqual(tf.wait_ready(lambda: next(states), timeout=3, interval=1, sleep=waits.append), 'ready')
        self.assertEqual(waits, [1, 1])
        with self.assertRaises(tf.DeliveryError): tf.wait_ready(lambda: 'processing', timeout=2, interval=1, sleep=lambda _: None)
    def test_next_build_scans_pages_and_uses_numeric_order(self):
        api = APIStub([{'data': [{'attributes': {'version': '9'}}, {'attributes': {'version': '10'}}], 'links': {'next': tf.API_ORIGIN+'/v1/builds?cursor=2'}},
                       {'data': [{'attributes': {'version': '12'}}]}])
        self.assertEqual(tf.next_build(api, '1.0', 2), 13)
    def test_non_numeric_server_build_fails_instead_of_reusing_number(self):
        with self.assertRaises(tf.DeliveryError): tf.next_build(APIStub([{'data': [{'attributes': {'version': '1.2.3'}}]}]), '1.0', 2)
    def test_external_or_nonautomatic_group_is_rejected(self):
        for attrs in [{'name':'Personal','isInternalGroup':False,'hasAccessToAllBuilds':True}, {'name':'Personal','isInternalGroup':True,'hasAccessToAllBuilds':False}]:
            with self.assertRaises(tf.DeliveryError): tf.personal_group(APIStub([{'data':[{'id':'group','attributes':attrs}]}]))

class CredentialTests(unittest.TestCase):
    def test_token_signature_and_claims(self):
        key=ec.generate_private_key(ec.SECP256R1())
        token=tf.make_token(key, 'KEY1234567', 'issuer', now=1000)
        parts=token.split('.')
        decode=lambda s: base64.urlsafe_b64decode(s+'='*(-len(s)%4))
        self.assertEqual(json.loads(decode(parts[0])), {'alg':'ES256','kid':'KEY1234567','typ':'JWT'})
        claims=json.loads(decode(parts[1])); self.assertEqual(claims, {'iss':'issuer','iat':1000,'exp':1600,'aud':'appstoreconnect-v1'})
        signature=decode(parts[2]); self.assertEqual(len(signature),64)
        der=utils.encode_dss_signature(int.from_bytes(signature[:32],'big'),int.from_bytes(signature[32:],'big'))
        key.public_key().verify(der, '.'.join(parts[:2]).encode(), ec.ECDSA(hashes.SHA256()))
    def test_setup_stores_private_files_outside_repo_and_rejects_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); source=root/'input.p8'
            key=ec.generate_private_key(ec.SECP256R1())
            source.write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
            config=root/'private'/'config.json'
            tf.configure(source, 'KEY1234567', 'issuer', config)
            stored=json.loads(config.read_text()); private=Path(stored['key_file'])
            self.assertEqual(config.stat().st_mode&0o777,0o600)
            self.assertEqual(private.stat().st_mode&0o777,0o600)
            self.assertEqual(private.parent.stat().st_mode&0o777,0o700)
            self.assertEqual(private.read_bytes(),source.read_bytes())
            with self.assertRaises(tf.DeliveryError): tf.configure(source, 'OTHER', 'issuer', config)
    def test_api_never_sends_bearer_to_foreign_origin(self):
        api=tf.AppleAPI(lambda: 'secret')
        for url in ['https://evil.example/v1/builds','http://api.appstoreconnect.apple.com/v1/builds','//evil.example/v1/builds']:
            with self.assertRaises(tf.DeliveryError): api.get(url)
    def test_api_auth_errors_are_actionable_without_token_leak(self):
        import urllib.error
        api=tf.AppleAPI(lambda: 'secret')
        with patch.object(api.opener, 'open', side_effect=urllib.error.HTTPError(tf.API_ORIGIN,401,'no',{},None)):
            with self.assertRaises(tf.DeliveryError) as error: api.get('/v1/builds')
        self.assertIn('401',str(error.exception)); self.assertNotIn('secret',str(error.exception))
    def test_http_redirect_cannot_forward_token(self):
        import urllib.request
        with self.assertRaises(tf.DeliveryError): tf.NoRedirect().redirect_request(urllib.request.Request(tf.API_ORIGIN),None,302,'',{},'https://evil.example')

class WorkflowTests(unittest.TestCase):
    def test_build_settings_json_stays_parseable_with_stderr_warnings(self):
        with tempfile.TemporaryDirectory() as directory:
            log=Path(directory)/'build-settings.json'
            tf.run_logged([sys.executable,'-c','import sys; print("[]"); print("warning: multiple destinations",file=sys.stderr)'],log)
            self.assertEqual(json.loads(log.read_text()),[])
            self.assertIn('multiple destinations',log.with_suffix('.stderr.log').read_text())

    def test_failed_tests_prevent_archive_and_upload(self):
        calls=[]
        def fail(command, log):
            calls.append(command)
            raise tf.DeliveryError('test failed')
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(tf.DeliveryError):
            tf.run_tests(Path(directory),fail,'simulator')
        self.assertEqual(len(calls),1)
        self.assertNotIn('archive',calls[0])
    def test_pipeline_stops_before_archive_when_native_tests_fail(self):
        group={'data':[{'id':'group','attributes':{'name':'Personal','isInternalGroup':True,'hasAccessToAllBuilds':True}}]}
        api=APIStub([group,{'data':{'attributes':{'bundleId':tf.BUNDLE_ID}}},{'data':[]}])
        calls=[]
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)
            def run(command, log):
                calls.append(command)
                if '-showBuildSettings' in command:
                    log.write_text(json.dumps([{'target':'Pentaphor','buildSettings':{'PRODUCT_BUNDLE_IDENTIFIER':tf.BUNDLE_ID,'DEVELOPMENT_TEAM':tf.TEAM_ID,'MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'2'}}]))
                elif 'test' in command and command[0]=='xcodebuild': raise tf.DeliveryError('native tests failed')
            with self.assertRaises(tf.DeliveryError): tf.deploy({},api,output,'simulator',run)
            self.assertFalse(any('archive' in call or '-exportArchive' in call for call in calls))
            self.assertEqual(json.loads((output/'delivery.json').read_text())['build'],'3')
    def test_api_transient_server_failure_retries_and_recovers(self):
        import io,urllib.error
        api=tf.AppleAPI(lambda:'secret')
        with patch.object(api.opener,'open',side_effect=[urllib.error.HTTPError(tf.API_ORIGIN,503,'no',{},None),io.BytesIO(b'{"data":[]}')]), patch('testflight.time.sleep') as sleep:
            self.assertEqual(api.get('/v1/builds'),{'data':[]})
            sleep.assert_called_once_with(2)

    def test_commands_keep_api_auth_and_internal_only_export(self):
        args=tf.auth_args({'key_file':'/private/Auth Key.p8','key_id':'KEY1234567','issuer_id':'issuer'})
        self.assertEqual(args,['-allowProvisioningUpdates','-authenticationKeyPath','/private/Auth Key.p8','-authenticationKeyID','KEY1234567','-authenticationKeyIssuerID','issuer'])
        options=tf.export_options()
        self.assertTrue(options['testFlightInternalTestingOnly'])
        self.assertFalse(options['manageAppVersionAndBuildNumber'])
        self.assertEqual(options['teamID'],'NX53XT8XMU')

if __name__=='__main__': unittest.main()
