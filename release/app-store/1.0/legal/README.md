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
5. Verify provider/sign-in sections against current Apple, Google, and Game Center
   behavior before production; update them when another provider is added.
6. Publish over HTTPS, test both pages on phone and desktop, and add the final URLs in App Store Connect.

The pages must state that iOS does **not** submit Game Center scores or achievements
directly. PHP owns the implemented prerelease publication lanes. Before production,
verify that the public text describes current Arcade/Multiplayer publication,
Apple retention, account deletion, and any disabled/held delivery accurately.
