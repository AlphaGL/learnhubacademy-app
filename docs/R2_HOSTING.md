# Hosting the APK on Cloudflare R2

The build workflow uploads each release to a Cloudflare R2 bucket and serves it
from your own domain (e.g. `https://dl.learnhubacademy.org`). Users never see
GitHub, and it stays online even if learnhubacademy.org's main site is down.
R2 egress is free.

One-time setup below. After this, every release is automatic — just run the
**Build & Release APK** workflow with a new version number.

---

## 0. Prerequisite: push this repo to GitHub
The release workflow (`.github/workflows/build_apk.yml`) runs on GitHub
Actions, so the project needs to live in a GitHub repo first (private is
fine). If it isn't already:
```bash
git init
git add .
git commit -m "Initial commit"
gh repo create learnhub_app --private --source=. --push
# or create the repo on github.com and: git remote add origin <url> && git push -u origin main
```

## 1. Your domain is already on Cloudflare
`learnhubacademy.org` is already managed by Cloudflare (confirmed in your
dashboard) — no nameserver changes needed, skip straight to step 2.

## 2. Create the R2 bucket
- Dashboard → **R2** → **Create bucket** → name it `learnhub-app` (any name,
  just keep it consistent with the `R2_BUCKET` variable in step 4).
- Open the bucket → **Settings** → **Public access → Custom Domains** →
  **Connect Domain** → enter `dl.learnhubacademy.org`. Cloudflare adds the DNS
  record and enables public read for that hostname automatically.
- Test later: `https://dl.learnhubacademy.org/learnhub-latest.apk` should
  download.

## 3. Create R2 API credentials (for GitHub Actions)
- R2 → **Manage R2 API Tokens** → **Create API Token**.
- Permission: **Object Read & Write**, scoped to the `learnhub-app` bucket.
- Copy the **Access Key ID** and **Secret Access Key** (shown once).
- Also note your **Account ID** (R2 overview page, right sidebar).

## 4. Add GitHub Actions secrets & variables
In the **app repo** → Settings → Secrets and variables → Actions.

**Secrets** (Secrets tab):
| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | `certutil -encode android\learnhub-upload.jks tmp.b64` then paste the base64 (see step 5) |
| `STORE_PASSWORD` | from `android/key.properties` — ask me if you don't have it handy |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | same as `STORE_PASSWORD` (PKCS12 keystores require them equal) |
| `SUPABASE_URL` | from `dart_define.json` |
| `SUPABASE_ANON_KEY` | from `dart_define.json` |
| `GOOGLE_WEB_CLIENT_ID` | from `dart_define.json` |
| `CLOUDINARY_CLOUD_NAME` | from `dart_define.json` |
| `PAYSTACK_PUBLIC_KEY` | from `dart_define.json` |
| `SUPABASE_SERVICE_KEY` | Supabase → Project Settings → API → `service_role` key (**not** the anon key — needed to publish the release row, since `app_release` only grants `select` to anon/authenticated) |
| `R2_ACCESS_KEY_ID` | from step 3 |
| `R2_SECRET_ACCESS_KEY` | from step 3 |

**Variables** (Variables tab):
| Name | Value |
|---|---|
| `R2_ACCOUNT_ID` | your Cloudflare account id |
| `R2_BUCKET` | `learnhub-app` |
| `R2_PUBLIC_URL` | `https://dl.learnhubacademy.org` (no trailing slash) |

## 5. Encode the keystore for the KEYSTORE_BASE64 secret
The keystore itself never goes in the repo (it's git-ignored) — only a
base64-encoded copy goes into the GitHub secret:
```powershell
certutil -encode android\learnhub-upload.jks tmp.b64
# open tmp.b64, strip the ----BEGIN/END CERTIFICATE---- lines, paste the rest
# as the KESTORE_BASE64 secret, then delete tmp.b64
```

## 6. Ship a build
Actions → **Build & Release APK** → Run → enter the version (e.g. `1.0.1`).

The workflow will:
1. Build a signed, **obfuscated** APK.
2. Upload it to R2 as `learnhub-<version>.apk` **and** `learnhub-latest.apk`.
3. Register the release in Supabase's `app_release` table so existing users
   get the in-app update prompt.

## Links to use
- **Website download button** → `https://dl.learnhubacademy.org/learnhub-latest.apk`
  (always the newest build).
- **In-app updates** → handled automatically; the updater downloads the
  versioned URL registered in Supabase and opens the installer.

---

### Notes
- Old versions stay in the bucket (each has its own filename), so you keep a
  full history and can roll back by inserting an `app_release` row pointing
  at an older `learnhub-<version>.apk`.
- Debug symbols for each build are saved as a workflow **artifact**
  (`debug-symbols-<version>`) so Crashlytics stack traces remain readable
  despite obfuscation.
- Never put a **secret** key (Supabase `service_role`, Firebase
  service-account) in the app — only the publishable/anon key, which is safe
  to expose because access is governed by Row-Level Security.
