"""deploy/web_apply.sh: refuses the wrong commit, installs the web pages with a
backup, and restores the backup when a check fails.

Runs the real script against a throwaway git clone, app dir and nginx site,
with stub sudo / nginx / systemctl / curl on PATH, so nothing on the host is
touched.
"""
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

BACKEND = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = BACKEND / "deploy" / "web_apply.sh"
PAGES = ("privacy-policy.html", "support.html", "terms.html", "delete-account.html")

STUBS = {
    "sudo": '#!/bin/sh\nexec "$@"\n',
    "nginx": "#!/bin/sh\nexit 0\n",
    "systemctl": "#!/bin/sh\nexit 0\n",
    # Health answers ok; public pages are served from the installed app dir,
    # except the page named in $BROKEN_PAGE.
    "curl": """#!/bin/sh
for a; do url="$a"; done
case "$url" in
  *127.0.0.1:8787/health) echo '{"status": "ok"}' ;;
  */"$BROKEN_PAGE") exit 22 ;;
  *) cat "$APP_DIR/static/${url##*/}" ;;
esac
""",
}


@unittest.skipUnless(shutil.which("bash") and shutil.which("git"), "needs bash and git")
class WebApplyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        # A clone holding the files the script deploys.
        self.repo = self.tmp / "repo"
        src = self.repo / "rep-counter-ai-main" / "backend"
        (src / "static").mkdir(parents=True)
        (src / "deploy").mkdir()
        for name in ("server.py", "ai_provider.py"):
            shutil.copy(BACKEND / name, src / name)
        for page in PAGES:
            shutil.copy(BACKEND / "static" / page, src / "static" / page)
        shutil.copy(BACKEND / "deploy" / "repcoach-ai.nginx", src / "deploy" / "repcoach-ai.nginx")
        self.git("init", "-q")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "fixture")
        self.sha = self.git("rev-parse", "HEAD").strip()
        # The "VPS": an app dir with the old version and an nginx site.
        self.app = self.tmp / "app"
        (self.app / "static").mkdir(parents=True)
        (self.app / ".env").write_text("BIND_HOST=127.0.0.1\n")
        (self.app / "server.py").write_text("# old server\n")
        (self.app / "ai_provider.py").write_text("# old provider\n")
        (self.app / "static" / "privacy-policy.html").write_text("old policy\n")
        self.site = self.tmp / "nginx-site"
        self.site.write_text("# old site\n")
        self.backups = self.tmp / "backups"
        stubs = self.tmp / "bin"
        stubs.mkdir()
        for name, body in STUBS.items():
            (stubs / name).write_text(body)
            (stubs / name).chmod(0o755)
        self.path = f"{stubs}:{os.environ['PATH']}"

    def git(self, *args):
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.invalid",
                   GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid")
        return subprocess.run(["git", "-C", str(self.repo), *args], env=env, check=True,
                              capture_output=True, text=True).stdout

    def run_script(self, **extra):
        env = {
            "PATH": self.path,
            "HOME": str(self.tmp),
            "REPO_DIR": str(self.repo),
            "APP_DIR": str(self.app),
            "NGINX_SITE": str(self.site),
            "BACKUP_ROOT": str(self.backups),
            "PUBLIC_URL": "https://example.invalid",
            "EXPECTED_SHA": self.sha,
            "BROKEN_PAGE": "none",
        }
        env.update(extra)
        return subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True,
                              timeout=60)

    def assert_untouched(self):
        self.assertEqual((self.app / "server.py").read_text(), "# old server\n")
        self.assertEqual((self.app / "static" / "privacy-policy.html").read_text(), "old policy\n")
        self.assertFalse((self.app / "static" / "delete-account.html").exists())
        self.assertEqual(self.site.read_text(), "# old site\n")

    def test_script_is_valid_bash(self):
        subprocess.run(["bash", "-n", str(SCRIPT)], check=True)
        if shutil.which("shellcheck"):
            r = subprocess.run(["shellcheck", str(SCRIPT)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_requires_expected_sha(self):
        r = self.run_script(EXPECTED_SHA="")
        self.assertEqual(r.returncode, 2, r.stderr)
        self.assertIn("EXPECTED_SHA", r.stderr)
        self.assert_untouched()

    def test_refuses_another_commit(self):
        r = self.run_script(EXPECTED_SHA="0000000")
        self.assertEqual(r.returncode, 2, r.stderr)
        self.assertIn("not 0000000", r.stderr)
        self.assert_untouched()

    def test_refuses_local_changes(self):
        page = self.repo / "rep-counter-ai-main" / "backend" / "static" / "support.html"
        page.write_text(page.read_text() + "<!-- edit -->")
        r = self.run_script()
        self.assertEqual(r.returncode, 2, r.stderr)
        self.assertIn("local changes", r.stderr)
        self.assert_untouched()

    def test_installs_pages_with_a_backup(self):
        r = self.run_script(EXPECTED_SHA=self.sha[:7])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(f"WEB_DEPLOY=PASS sha={self.sha}", r.stdout)
        for page in PAGES:
            self.assertEqual((self.app / "static" / page).read_bytes(),
                             (BACKEND / "static" / page).read_bytes())
            self.assertIn(f"OK  https://example.invalid/{page}", r.stdout)
        self.assertEqual((self.app / "server.py").read_bytes(), (BACKEND / "server.py").read_bytes())
        self.assertEqual(self.site.read_bytes(), (BACKEND / "deploy" / "repcoach-ai.nginx").read_bytes())
        [backup] = list(self.backups.iterdir())
        self.assertIn(f"BACKUP_PATH={backup}", r.stdout)
        self.assertEqual((backup / "server.py").read_text(), "# old server\n")
        self.assertEqual((backup / "static" / "privacy-policy.html").read_text(), "old policy\n")
        self.assertEqual((backup / "nginx-site").read_text(), "# old site\n")
        self.assertEqual((backup / "DEPLOYED_SHA").read_text().strip(), self.sha)

    def test_failed_public_check_restores_the_backup(self):
        r = self.run_script(BROKEN_PAGE="delete-account.html")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("restoring", r.stderr)
        self.assertNotIn("WEB_DEPLOY=PASS", r.stdout)
        self.assertEqual((self.app / "server.py").read_text(), "# old server\n")
        self.assertEqual((self.app / "static" / "privacy-policy.html").read_text(), "old policy\n")
        self.assertFalse((self.app / "static" / "delete-account.html").exists())
        self.assertEqual(self.site.read_text(), "# old site\n")


if __name__ == "__main__":
    unittest.main()
