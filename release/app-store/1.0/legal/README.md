# PimPoPom Privacy and Support pages

These are dependency-free static pages for the public App Store URLs:

- `privacy.html` — Privacy Policy URL;
- `support.html` — Support URL and account-deletion instructions;
- `styles.css` — shared responsive presentation;
- `app-icon.png` — the shipped PimPoPom icon.

They contain no JavaScript, cookies, analytics, remote fonts, or external assets. Upload all four public files to one HTTPS directory and keep the relative links intact.

## Required owner review before upload

Replace every bracketed placeholder in both HTML files:

- `[LEGAL ENTITY]`
- `[PUBLICATION DATE]`
- `[SUPPORT EMAIL]`
- `[PRIVACY EMAIL]`
- `[MODERATION EMAIL]`
- `[BUSINESS ADDRESS IF REQUIRED]`
- `[SUPPORT RESPONSE TARGET]`
- `[SECURITY LOG RETENTION]`
- `[SUPPORT RECORD RETENTION]`
- `[PAYMENT RECORD RETENTION]`

Then:

1. Confirm the responsible entity matches the App Store seller and tax/legal records.
2. Confirm the retention periods with the deployed backend and applicable accounting requirements.
3. Review the children/general-audience paragraph against the final age questionnaire and ad treatment.
4. Compare the privacy disclosures with the exact Release archive's aggregate privacy report and App Store privacy answers.
5. Update the provider/sign-in sections before shipping Sign in with Apple or any other new identity provider.
6. Publish over HTTPS, test both pages on phone and desktop, and add the final URLs in App Store Connect.

The pages deliberately say that the current client does **not** submit scores or achievements to Game Center. Update that statement only after the accepted Hostinger-owned Game Center mirrors are actually implemented and released.
