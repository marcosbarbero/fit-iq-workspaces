#  Schema Definition

This directory contains the schema definitions for the FitIQ application. The schema files define the structure of the database, including tables, columns, data types, and relationships between tables.

## When to Use

Whenever a new database table is created or an existing table is modified, the corresponding schema definition file should be updated. This ensures that the database structure remains consistent with the application's data requirements.


## Changes required

* `PersistenceHelper`: Whenever a new version is introduced make sure to update the `typealiases` in this file to reflect any changes to the latest `SwiftData` models.
* `Schema Definitions`: Add new schema definition files or update existing ones to reflect changes in the database structure.
* `Naming Conventions`: The `@Model` classes **must** always use the `prefix` `SD` to differentiate them from regular Swift classes. This is crucial for maintaining clarity and consistency in the codebase.
