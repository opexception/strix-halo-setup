"""Offline guardrails; full Docker Compose merge checks live in scripts/validate.sh."""
from pathlib import Path
import subprocess
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]


class RepoTest(unittest.TestCase):
    def doc(self, name):
        return yaml.safe_load((ROOT / name).read_text())

    def test_scripts_parse(self):
        scripts = sorted((ROOT / 'scripts').glob('*.sh'))
        self.assertGreaterEqual(len(scripts), 6)
        subprocess.run(['bash', '-n', *map(str, scripts)], check=True)

    def test_all_stages_exist_and_no_inadvertent_exposure(self):
        expected = {
            1: {'ollama'},
            2: {'litellm'},
            3: {'litellm', 'openwebui'},
            4: {'caddy'},
        }
        for n, services in expected.items():
            with self.subTest(stage=n):
                data = self.doc(f'compose/stages/{n}.yml')
                self.assertEqual(set(data['services']), services)
                self.assertTrue(all('ports' in svc for svc in data['services'].values()))
        for name in ['ollama', 'gateway', 'chat', 'proxy']:
            data = self.doc(f'compose/components/{name}.yml')
            for service in data['services'].values():
                self.assertNotIn('ports', service, f'{name} component must never publish ports')
                self.assertNotIn('privileged', service, f'{name} must not run privileged')
                self.assertNotIn('network_mode', service)

    def test_no_bypass_of_litellm_from_chat(self):
        env = self.doc('compose/components/chat.yml')['services']['openwebui']['environment']
        self.assertEqual(env['ENABLE_OLLAMA_API'], 'false')
        self.assertIn('litellm:4000', env['OPENAI_API_BASE_URL'])
        self.assertIn('OPENWEBUI_API_KEY', env['OPENAI_API_KEY'])
        self.assertEqual(env['ENABLE_SIGNUP'], 'false')

    def test_gateway_has_db_and_access_control(self):
        gateway = self.doc('compose/components/gateway.yml')['services']
        self.assertIn('postgres', gateway)
        self.assertIn('LITELLM_MASTER_KEY', gateway['litellm']['environment'])
        self.assertIn('LITELLM_SALT_KEY', gateway['litellm']['environment'])
        self.assertNotIn('ports', gateway['postgres'])

    def test_proxy_separates_domains_and_backends(self):
        for name in ['public', 'internal']:
            text = (ROOT / f'config/caddy/Caddyfile.{name}').read_text()
            self.assertIn('litellm:4000', text)
            self.assertIn('openwebui:8080', text)
            self.assertIn('{$API_DOMAIN}', text)
            self.assertIn('{$CHAT_DOMAIN}', text)
            self.assertEqual('tls internal' in text, name == 'internal')

    def test_litellm_image_not_floating(self):
        env = (ROOT / '.env.example').read_text()
        self.assertIn('LITELLM_IMAGE=ghcr.io/berriai/litellm:v1.106.2', env)
        self.assertNotIn('LITELLM_IMAGE=ghcr.io/berriai/litellm:main-stable', env)


if __name__ == '__main__':
    unittest.main()
