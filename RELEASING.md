# Releasing ocpp-rails

Releases are published to [RubyGems.org](https://rubygems.org/gems/ocpp-rails)
automatically by GitHub Actions using **trusted publishing** (OIDC). No API keys
or secrets are stored anywhere — RubyGems mints a short-lived token scoped to this
repository and workflow at the moment of publish.

The workflow is [`.github/workflows/push_gem.yml`](.github/workflows/push_gem.yml).
It runs on any pushed tag matching `v*`, builds the gem from
[`ocpp-rails.gemspec`](ocpp-rails.gemspec), pushes it to RubyGems, and creates a
matching GitHub Release.

---

## One-time setup (before the first release)

This is done once, in a browser, by an owner of the gem/repo. It is already done
if `ocpp-rails` shows a trusted publisher under its RubyGems settings.

1. Sign in to <https://rubygems.org> (enable MFA on the account — the gemspec sets
   `rubygems_mfa_required`; trusted publishing satisfies this requirement).
2. Go to **<https://rubygems.org/profile/oidc/pending_trusted_publishers/new>**
   (Profile → Trusted Publishers → *Register a new trusted publisher* also gets you
   there). Because the gem is not published yet, you register a **pending** publisher
   — it converts to a normal one automatically after the first successful push.
3. Fill in exactly:
   | Field | Value |
   |-------|-------|
   | RubyGems gem name | `ocpp-rails` |
   | Repository owner | `trahfo` |
   | Repository name | `ocpp-rails` |
   | Workflow filename | `push_gem.yml` |
   | Environment (optional but recommended) | `release` |
4. Save.
5. In GitHub, create the matching environment: **Settings → Environments → New
   environment → `release`**. (Add protection rules such as required reviewers here
   if you want a human gate before any publish.)

> The workflow filename, repo owner/name, and environment must match the workflow
> **exactly**, or RubyGems will refuse the OIDC token.

---

## Cutting a release

1. Make sure `main` is green (`bin/rails test` and `bin/rubocop`) and you're on it.
2. Bump the version in [`lib/ocpp/rails/version.rb`](lib/ocpp/rails/version.rb)
   following [SemVer](https://semver.org/). While on `0.x`, treat minor bumps as
   potentially breaking.
3. Add a dated section to [`CHANGELOG.md`](CHANGELOG.md) describing the changes.
4. Commit both:
   ```bash
   git commit -am "Release vX.Y.Z"
   ```
5. Tag and push. The tag **must** be `v` + the exact version string:
   ```bash
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```
6. Watch the **Push gem to RubyGems** workflow in the Actions tab. When it goes
   green the gem is live at <https://rubygems.org/gems/ocpp-rails> and a GitHub
   Release has been created.

That's it — consumers can now `bundle add ocpp-rails` or `gem install ocpp-rails`.

---

## Manual fallback

If CI is unavailable and you have push rights (an owner listed via
`gem owner ocpp-rails`), you can publish from a trusted machine:

```bash
gem signin                 # one-time, uses your RubyGems credentials + MFA
gem build ocpp-rails.gemspec
gem push ocpp-rails-X.Y.Z.gem
```

Prefer the tag-based CI flow above — it needs no local credentials and keeps the
release reproducible.
