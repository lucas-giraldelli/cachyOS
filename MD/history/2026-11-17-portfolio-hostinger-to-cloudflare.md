# 2026-11-17 - Portfolio Moved from Hostinger to Cloudflare

Hostinger renewal notices came in for `lucasgiraldelli.dev`: a Premium Web Hosting plan
(R$ 395.88/year), an unused second Premium plan from a free trial (R$ 119.88/year), and the
`.dev` domain (R$ 98.99/year). About R$ 615/year in total.

The site is a static Astro build (no PHP, no database, no email on the domain), and the
zone's DNS was already on Cloudflare. So the hosting was dropped, the site moved to
Cloudflare Pages (free), and the domain is moving to Cloudflare Registrar (wholesale price,
about US$ 12/year for `.dev`).

## Where things were

- The registrar is not visible in `whois` for `.dev`. RDAP shows it:
  `curl -s https://pubapi.registry.google/rdap/domain/lucasgiraldelli.dev`. It listed
  "Hosting Concepts B.V. d/b/a Registrar.eu" (Openprovider), which is what Hostinger uses
  for `.dev`, not GoDaddy or HostGator.
- The site was served by Hostinger behind the Cloudflare proxy (`platform: hostinger`
  response header), deployed by a GitHub Actions `rsync` over SSH.
- The home services (`atlas`, `atlas-api`, `catalog`, `kite-api`, `media`) are Cloudflare
  Tunnel hostnames served by the `cloudflared` container on this PC. None of this touched
  them.

## Hostinger

- Auto-renew turned off for both Premium plans and the domain. The hosting now expires on
  2026-12-03, the domain on 2026-12-27.
- The "plan expires" banner in hPanel can be ignored, nothing is hosted there any more.

## Cloudflare Pages

In the `lucasgiraldelli-portfolio` repo:

- `.github/workflows/deploy.yml` now ends with
  `npx --yes wrangler@3.90.0 pages deploy dist --project-name=lucasgiraldelli-portfolio --branch=main`
  instead of the SSH + `rsync` steps.
- Repo secrets: `CLOUDFLARE_API_TOKEN` (account token, Cloudflare Pages: Edit, no expiry)
  and `CLOUDFLARE_ACCOUNT_ID`. `SSH_PRIVATE_KEY` is left over from Hostinger.

Pitfalls hit on the way:

- **wrangler 4 converts Pages projects to Workers.** `wrangler pages project create`
  delegated to Workers, ran an Astro autoconfig and added `wrangler` to `package.json`
  before failing. The changes were reverted and the project was created through the API
  (`POST /accounts/{id}/pages/projects`). CI pins wrangler 3 for the same reason.
- **`cloudflare/wrangler-action@v3` fails with pnpm 12.** It installs wrangler with
  `pnpm add`, which pnpm 12 refuses (`ERR_PNPM_IGNORED_BUILDS`). Running wrangler through
  `npx` keeps it out of the project.
- **`gh secret set` stored an empty token** the first time. Re-setting it from a file
  (`gh secret set NAME < file`) fixed the "set a CLOUDFLARE_API_TOKEN" error.

## DNS

Deleted the Hostinger records: `A` and `AAAA` on the apex, `A` on `ftp`, and the `www`
CNAME. Then both `lucasgiraldelli.dev` and `www.lucasgiraldelli.dev` were added under the
Pages project's Custom domains, which created the CNAMEs to
`lucasgiraldelli-portfolio.pages.dev` (flattened at the apex). Both went active within
about 3 minutes. The tunnel records and the `_atproto` TXT (Bluesky handle) were kept.

Checked afterwards: apex and `www` return 200 from Pages, `/cv/` and the CV PDF load, `http`
redirects to `https`, and the tunnel hostnames answer as before.

## Domain transfer (in progress)

1. hPanel → Domains → `lucasgiraldelli.dev` → Manage → Transfer: turn off "Bloqueio de
   domínio" and use "Receber código" for the auth (EPP) code.
2. Cloudflare dashboard → Domains → Transfers, paste the code, pay one year. The year is
   added on top of the current expiry.

The lock change takes a while to reach the registry. RDAP `status` must lose
`client transfer prohibited` before Cloudflare accepts the transfer. A transfer takes up to
5 days, so it has to start by about 2026-12-15 to beat the 2026-12-27 expiry.

## Leftovers

- Delete the `SSH_PRIVATE_KEY` secret from the portfolio repo.
- `~/.config/cf-pages-token` holds a copy of the Pages token, used for the one-off API
  calls. Delete it if it isn't needed.
