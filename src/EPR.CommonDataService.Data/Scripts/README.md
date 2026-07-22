# Common Data API SQL Migration Notice

## Overview

As part of **[EMR-89](https://eaflood.atlassian.net/browse/EMR-89)**, the SQL components previously maintained within the **common-data-api** repository were migrated to the **[epr-data-sqldb](https://github.com/DEFRA/epr-data-sqldb)** repository.

- **Change Reference:** [EMR-89](https://eaflood.atlassian.net/browse/EMR-89)
- **Production Migration Date:** 20th July 2026
- **Affected Components:** SQL objects previously stored in the `common-data-api` repository
- **New Repository:** [epr-data-sqldb](https://github.com/DEFRA/epr-data-sqldb)

This migration was undertaken to consolidate SQL database objects into the dedicated SQL database repository and align them with the standard database deployment process.

---

## Making Future Changes

All future changes to these SQL objects **must** be made in the **[epr-data-sqldb](https://github.com/DEFRA/epr-data-sqldb)** repository.

The SQL artefacts in the `common-data-api` repository should no longer be considered the source of truth.

Before planning or submitting changes, please contact the **Analytics and Insights Platform** team to understand the current release cadence, deployment process, and any applicable change windows.

> **Important:** Do not submit changes to the legacy SQL artefacts in the `common-data-api` repository. All development, review, and deployment activities should be performed through the `epr-data-sqldb` repository.