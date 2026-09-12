# Data deletion

The local Hisab application does not create accounts or store app records on a
service. The public deletion page is:

`https://hisab.shenepoy.com/delete-account/`

It is also linked from the public privacy page and is suitable for the Google
Play and Apple App Store legal-information fields.

## Delete local records

Use Settings → Data & Backup to remove records from the app. Exported JSON,
CSV, and ZIP backups are separate files and must be deleted from wherever they
were saved.

To remove all remaining local data, clear the app's storage on Android, delete
the app on iOS, or clear the site's storage in the browser on web. This also
removes local receipts and transaction-scanner drafts that were not exported.

Because this application has no account or remote data store, there is no
separate account-closure request to process. If a release appears to have
created an account or retained data outside the local app, contact the
maintainer through the public issue tracker without sending sensitive records.
