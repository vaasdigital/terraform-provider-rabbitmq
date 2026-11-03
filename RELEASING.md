# Releasing

Every merge to `master` whose commits warrant a release is tested, tagged and
published automatically by `.github/workflows/release-on-merge.yml`:

| Commits since the last release            | Release        |
|-------------------------------------------|----------------|
| `type!:` or a `BREAKING CHANGE:` footer   | major (`2.0.0`) |
| `feat:`                                   | minor (`1.12.0`) |
| `fix:` / `perf:`                          | patch (`1.11.1`) |
| only `docs:`, `test:`, `chore:`, Dependabot | none          |

The release workflow builds the binaries with GoReleaser, signs the checksums
with the GPG key in the `GPG_PRIVATE_KEY` / `PASSPHRASE` repository secrets, and
creates a GitHub Release. The Terraform Registry picks the release up through its
webhook and verifies the signature against the public key registered for the
`vaasdigital` namespace.

A release can also be made by hand by pushing a `v*` tag.

## When the signing key expires

### Symptoms

- The `release` job fails at the GoReleaser signing step with an error
  mentioning an expired key.
- The tag exists on GitHub but has no GitHub Release, and the version never
  appears on the Terraform Registry.

Releases published before the expiry keep installing; only new releases are
blocked.

### Renew the key

Extend the expiry of the existing key rather than creating a new one. The key ID
stays the same, so signatures on earlier releases remain valid.

1. Import the private key from the password manager if it is not already in
   your keyring:

   ```sh
   gpg --import private-key.asc
   ```

2. Find the fingerprint and extend the expiry:

   ```sh
   gpg --list-secret-keys --keyid-format=long
   gpg --quick-set-expire <FINGERPRINT> 5y
   gpg --quick-set-expire <FINGERPRINT> 5y '*'   # subkeys
   ```

3. Export both halves. The new expiry is stored in the key itself, so both
   copies must be replaced:

   ```sh
   gpg --armor --export <FINGERPRINT> > public-key.asc
   gpg --armor --export-secret-keys <FINGERPRINT> > private-key.asc
   ```

4. In GitHub, **Settings → Secrets and variables → Actions**, replace
   `GPG_PRIVATE_KEY` with the contents of `private-key.asc`. `PASSPHRASE` is
   unchanged.

5. On [registry.terraform.io](https://registry.terraform.io), **User Settings →
   Signing Keys**, remove the old key for the `vaasdigital` namespace and add the
   contents of `public-key.asc`.

6. Store the updated `private-key.asc` in the password manager, then delete the
   exported files:

   ```sh
   rm public-key.asc private-key.asc
   ```

7. Note the new expiry date in the team calendar, with a reminder a month
   ahead.

### Publish the blocked release

The tag from the failed run already exists, so do not create a new one. Open the
failed **release-on-merge** run under **Actions** and choose **Re-run failed
jobs**. The release job runs again for the same tag.

If the run can no longer be re-run, delete the tag and push it again, which
triggers `release.yml` directly:

```sh
git push origin :refs/tags/vX.Y.Z
git tag -f vX.Y.Z <commit>
git push origin vX.Y.Z
```

## When the signing key is lost or compromised

Renewal is not possible without the private key, and a leaked key must not be
used again.

1. If compromised, revoke it so it can no longer be trusted:
   `gpg --gen-revoke <FINGERPRINT>` and import the certificate.
2. Generate a new key: `gpg --full-generate-key`, choosing **RSA and RSA**,
   4096 bits. The registry does not accept the default ECC type.
3. Follow steps 3–7 above with the new key, adding it to the registry alongside
   or instead of the old one.

Releases signed with a revoked key should be considered untrusted; publish a new
release signed with the new key.
