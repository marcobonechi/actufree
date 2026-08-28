# Getting Actufree to testers on Google Play

The target is the **Internal testing** track: up to 100 testers, invited by
email, no review queue, a build is usually installable minutes after upload.
Closed/open testing and production all sit behind extra requirements; internal
testing is the short path to "my testers have it".

Everything in this repo that a release needs is ready. What is left is a
keystore (step 1), a public privacy-policy URL (step 2), and the Play Console
work (steps 4-8), which needs your Google account and cannot be done for you.

## What is already done

- `android/app/build.gradle.kts` reads release signing from
  `android/key.properties` and falls back to the debug key when that file is
  absent, so nothing breaks before step 1.
- Application ID `ai.sidevibe.actufree`, version `1.0.0+1`, targetSdk 36 —
  which is what Play requires of new apps from 31 August 2026.
- `flutter build appbundle --release` succeeds today (47.5 MB bundle).
- The release manifest requests **no** permissions — no `INTERNET`, nothing at
  runtime. The privacy claims in `docs/privacy.html` are enforced by the
  manifest, not just asserted.
- Store listing copy: `store/listing.md`. Icon, feature graphic, and four
  phone screenshots: this folder, all at the sizes Play requires.
- Privacy policy written: `docs/privacy.html`.

## 1. Create the upload keystore [DONE]

`/Users/marcob/actufree-upload.jks` exists and the key inside it checks out:

- Alias `upload`, JKS, 2048-bit RSA, `PrivateKeyEntry`
- Valid to 13 Jan 2054, comfortably past Play's 22 Oct 2033 floor
- SHA-256 `FA:21:F5:92:76:5A:CE:0F:47:2C:EA:A0:E5:D3:DC:33:B9:0B:15:E2:6B:25:EE:33:25:5B:DD:11:9B:B4:E4:36`
- Confirmed to be a different key from `~/.android/debug.keystore`

That fingerprint is public information — it is worth keeping here so a swapped
or regenerated key is obvious. Play will show the same value for the upload
certificate once the first bundle is uploaded; if the two ever disagree, stop.

Back up the `.jks` and its password somewhere durable (password manager). Play
App Signing means Google holds the real app signing key, so a lost upload key
can be reset through support — but that is a ticket and a wait, and losing
both is unrecoverable.

`keytool` will suggest migrating JKS to PKCS12. Ignore it: JKS is what Flutter
documents, Gradle reads it fine, and PKCS12 cannot hold a key password that
differs from the store password.

### `key.properties` — done

`puzzles/app/android/key.properties` exists, mode 0600, gitignored, pointing at
alias `upload` and the keystore path above. It holds the keystore password in
plain text, which is why it is gitignored and why it should never be pasted
into a chat or a ticket.

If you ever need to recreate it (new machine, or you rotate the password), this
prompts without echoing and keeps the password out of shell history:

```bash
cd /Users/marcob/actufree/puzzles/app/android && printf "Keystore password: " && read -rs KSPW && echo && printf "storePassword=%s\nkeyPassword=%s\nkeyAlias=upload\nstoreFile=/Users/marcob/actufree-upload.jks\n" "$KSPW" "$KSPW" > key.properties && chmod 600 key.properties && unset KSPW && echo "key.properties written"
```

(Works in both bash and zsh — `read -rs VAR` with a separate `printf` prompt is
the portable form; `read -rs "VAR?prompt"` is zsh-only and `read -rsp` is
bash-only.)

That assumes the key password matches the store password — true if you pressed
Return at the "key password" prompt. If you set a different one, edit the
`keyPassword` line afterwards.

The file is gitignored (`android/.gitignore:12`, verified), so it will not be
committed.

## 2. Publish the privacy policy [DONE]

Done — GitHub Pages is serving `/docs` from `main`, and the bytes on the live
page are identical to the committed `docs/privacy.html`. Both URLs return 200
and are the ones the listing uses:

- https://sidevibe.github.io/actufree/
- https://sidevibe.github.io/actufree/privacy.html

Re-check these before each release: Play rechecks the policy URL, and a listing
pointing at a 404 will hold up a rollout.

## 3. Build the signed bundle [DONE]

Done on 28 Aug 2026. `key.properties` is in place (mode 0600, gitignored) and
the bundle at
`puzzles/app/build/app/outputs/bundle/release/app-release.aab` (47.5 MB) is
signed with the upload key — certificate SHA-256 matches the fingerprint in
step 1 exactly, and is confirmed *not* to be the debug key. Package
`ai.sidevibe.actufree`, versionCode 1.

That file is what you upload in step 7.

To rebuild later:

```bash
cd /Users/marcob/actufree/puzzles/app && flutter build appbundle --release
```

Confirm it is signed with the upload key and not the debug key — the owner
line must show what you typed in step 1, not `CN=Android Debug`:

```bash
keytool -printcert -jarfile /Users/marcob/actufree/puzzles/app/build/app/outputs/bundle/release/app-release.aab
```

The artifact to upload is
`puzzles/app/build/app/outputs/bundle/release/app-release.aab`.

## 4. Developer account — registering fresh

The previous account was closed for inactivity, so this is a new registration:
25 USD again (the old fee is not refunded or transferable) at
https://play.google.com/console/signup.

Package name `ai.sidevibe.actufree` is unaffected. Closed accounts burn the
package names they *published*, and the old account never published anything,
so the name is free.

The closure is final: "closed due to inactivity, and can't be reactivated."
There is no appeal path, and the original 25 USD is gone.

### Why it closed, and how not to repeat it

Google closes a developer account that "was created more than a year ago and
has never submitted an app for review". That is almost certainly what happened
— an account registered in advance, then never shipped from.

The lesson for the new account: **register when you are ready to submit, not
before.** Registering now is right because a build is ready today. Registering
"to have it" and shipping a year later walks into the same closure.

The other closure rule, for later: apps under 1,000 lifetime installs whose
account has not verified its phone and contact email and has not opened Play
Console in 180 days. Verify both contact fields during setup and this one
never applies.

### Which Google account to register with

Unresolved: whether the Google account behind a closed developer account can
register a fresh one. Google's policy page does not say, and the developer
community has repeated reports of exactly this being stuck ("can't create new
developer account with same Google account", "email locked in loop"). Those
are user reports, not Google statements.

So: try the old Google account first, and if the flow loops or refuses, do not
fight it — register with a different Google account. Nothing in this repo is
tied to which account owns the developer profile.

Whichever account is used becomes the permanent owner of the developer
account and cannot be swapped later without a support-driven transfer, so pick
one that will outlive the project — a `sidevibe.ai` address rather than a
personal inbox, if this is meant to be Sidevibe's.

### Account type — decided at signup, permanent

| | Personal | Organization |
| --- | --- | --- |
| Verification | Government ID | D-U-N-S number + org details |
| Time to verify | Hours to ~2 days | Days to weeks if no D-U-N-S yet |
| Developer name shown | Your name | `Sidevibe` |
| Closed-testing requirement | **12 testers, 14 days, before production** | **Exempt** |

The last row is the one that matters. A personal account created after
13 Nov 2023 must run a closed test with at least 12 testers who stay opted in
for 14 continuous days before it can even apply for production access — and
the application itself is then reviewed. Organization accounts skip that.

Confirm the exemption on the signup flow before choosing; Google has adjusted
these rules more than once.

**Neither choice affects testers.** Internal testing is available to both as
soon as the account is verified, so the plan below is unchanged either way.
The fork only decides how long a public launch takes.

Recommendation: if Sidevibe is a real legal entity, register as an
organization — the D-U-N-S wait is likely shorter than the 14-day test plus
review, and it is a cost paid once. If it is not an entity, go personal, and
start the 12-tester closed test the same week you start internal testing so
the 14 days run in the background.

## 5. Create the app

Play Console -> Create app.

- App name: `Actufree`
- Default language: English (United States)
- App or game: **Game**
- Free or paid: **Free** (irreversible — a free app can never become paid)
- Declarations: developer program policies, US export laws.

## 6. App content declarations

Play blocks rollout, internal testing included, until this section is
complete. The answers for this app:

| Section | Answer |
| --- | --- |
| Privacy policy | `https://sidevibe.github.io/actufree/privacy.html` |
| Ads | No, the app contains no ads |
| App access | All functionality available without restrictions — no login |
| Content rating | Questionnaire, category Game. No violence, no sexuality, no language, no controlled substances, no gambling, no user interaction, no data shared, no location. Comes out Everyone / PEGI 3. |
| Target audience | Recommend **13+**. The app is suitable for any age, but selecting an under-13 bracket opts you into the Families policy (extra review, ad-format rules, a Families-specific declaration). Choose an under-13 bracket only if you want kids browsing to find it. |
| Data safety | **No data collected, no data shared.** Play counts only data that leaves the device; the preference, saved games, and best score stay in the app's private storage, so they are not "collected". No data types to declare. |
| Government apps | No |
| Financial features | None |
| Health | No |

## 7. Upload the build to internal testing

Testing -> Internal testing -> Create new release.

- Let Play App Signing generate the app signing key (the default). Your `.jks`
  from step 1 is the *upload* key only.
- Upload `app-release.aab`.
- Release name: `1.0.0 (1)`.
- Release notes: the block at the bottom of `store/listing.md`.
- Save -> Review release -> Start rollout to Internal testing.

The store listing (step 8) can be filled in either before or after this, but
rollout will not start until both it and step 6 are complete.

## 8. Store listing

Main store listing -> paste each field from `store/listing.md` and upload the
six images from `store/`.

## 9. Invite the testers

Internal testing -> Testers -> create an email list, or point it at a Google
Group (a group scales better — you add people without touching the Console).
Every tester needs the Google account they actually use on their phone.

Then copy the opt-in link from that page and send it to them. Each tester has
to open it and accept before Play will show them the app; the link is
per-track and does not expire. First install can take a few minutes to appear
after they opt in.

## Later builds

Bump the build number in `puzzles/app/pubspec.yaml` — `1.0.0+1` -> `1.0.0+2`
— before every upload. Play rejects a bundle whose version code it has already
seen, and the version code comes from the number after the `+`.
