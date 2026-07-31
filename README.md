# Nexora — Inventory & POS platform

A modular, multi-tenant Inventory + POS system. Built as a **platform core** with
pluggable **business modules**, so each company can have features locked or
unlocked individually.

## Architecture

```
lib/
├── main.dart                 # Firebase init + graceful "not configured" screen
├── app.dart                  # MaterialApp.router
├── firebase_options.dart     # PLACEHOLDER — run `flutterfire configure`
├── core/
│   ├── auth/                 # AuthRepository (interface) + Firebase impl + UI
│   ├── profile/              # UserProfile (uid → company + role)
│   ├── company/              # Company + Plan + CompanyRepository (+ Firestore impl)
│   ├── permissions/          # Perm keys + built-in Roles
│   ├── modules/              # ModuleId + ModuleManifest + ModuleRegistry
│   ├── access/               # Access (the 3-way gate) + gate widgets
│   ├── shell/                # HomeShell (module-driven nav), splash
│   ├── router/               # go_router with auth redirects
│   └── theme/
└── modules/
    └── dashboard/            # First module screen (KPI placeholders)
```

### The modular design (how feature-locking works)

Access is resolved by three independent switches (see `core/access/access.dart`):

1. **Module enabled for the company** — `Company.hasModule()`.
   Resolution order: core modules always on → per-company override → plan bundle.
2. **Dependencies enabled** — e.g. POS requires Inventory.
3. **User role permission** — `UserProfile.can('inventory.create')`.

Plus **feature flags** (`inventory.barcode`, etc.) for finer control *within* a
module.

Stored in Firestore on the company document:

```jsonc
companies/{id} {
  "plan": "business",
  "modules":  { "crm": true, "payroll": false },   // per-company overrides
  "features": { "inventory.barcode": true }
}
```

To lock a feature for one company: set `modules.<id> = false` (whole module) or
`features.<key> = false` (single feature) on that company's doc. Nothing else
changes.

### Why the repository interfaces matter

`AuthRepository` and `CompanyRepository` are **interfaces**. Today they're backed
by Firebase (`FirebaseAuthRepository`, `FirestoreCompanyRepository`). When you
build the custom backend, write `ApiAuthRepository` / `ApiCompanyRepository`,
swap the two provider lines in `auth_providers.dart` / `company_providers.dart`,
and the rest of the app is untouched.

## Getting started

1. **Create a Firebase project** at <https://console.firebase.google.com> and
   enable **Email/Password** auth + **Cloud Firestore**.
2. **Configure the app** (needs your Firebase login — run it yourself):
   ```bash
   flutterfire configure
   ```
   This overwrites `lib/firebase_options.dart` with real values.
3. **Deploy the security rules** in `firestore.rules`.
4. **Run:**
   ```bash
   flutter run -d chrome     # or windows / a device
   ```

## Verify

```bash
flutter analyze
flutter test
```

## Roadmap (next)

- Inventory module: product CRUD, categories, stock movements.
- POS module: cart, checkout, offline support, receipt.
- Dashboard KPIs wired to real data (pre-computed counters via Cloud Functions —
  Firestore can't aggregate cheaply).
- Admin: module/feature toggle UI for the owner (writes the maps above).
