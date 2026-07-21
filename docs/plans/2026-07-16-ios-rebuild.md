# ClassTrace iOS Rebuild Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an independent ClassTrace iOS and API codebase that reaches functional parity with the usable WeChat mini-program while replacing WeChat-specific identity, transport, notification, commerce, and VIP architecture.

**Architecture:** A SwiftUI feature-first client consumes a versioned REST API. The backend is a TypeScript modular monolith backed by PostgreSQL, with explicit Identity, Teaching, Commerce, Entitlement, and Notification boundaries. The original mini-program remains read-only and serves as the regression baseline.

**Tech Stack:** SwiftUI, Swift Concurrency, URLSession, Keychain, SwiftData; TypeScript, NestJS, PostgreSQL, Prisma, OpenAPI, Jest; APNs, StoreKit 2, object storage.

---

### Task 1: Establish repository and architecture guardrails

**Files:**
- Create: `README.md`
- Create: `docs/architecture/system-architecture.md`
- Create: `docs/architecture/feature-parity.md`
- Create: `docs/design/ios-design-system.md`
- Create: `docs/adr/*.md`

**Steps:**
1. Record the original mini-program as read-only source material.
2. Document module boundaries, data ownership, API envelopes and failure modes.
3. Document feature parity and iOS design rules.
4. Review that no target design depends on openid or direct cloud-function actions.

### Task 2: Create the API foundation

**Files:**
- Create: `services/api/package.json`
- Create: `services/api/src/main.ts`
- Create: `services/api/src/app.module.ts`
- Create: `services/api/src/common/**`
- Create: `services/api/test/**`

**Steps:**
1. Write a failing health endpoint integration test.
2. Add NestJS bootstrap, request IDs, global validation, error filter and response envelope.
3. Run tests and verify the success and error JSON contracts.
4. Add OpenAPI generation.

### Task 3: Define the PostgreSQL core schema

**Files:**
- Create: `services/api/prisma/schema.prisma`
- Create: `services/api/prisma/migrations/**`

**Steps:**
1. Model platform-independent users and identities.
2. Model students, guardians, courses, classes, members and sessions.
3. Model append-only hour ledger and attendance.
4. Model teaching orders, payment events, subscriptions and entitlements separately.
5. Add unique constraints for idempotency and provider events.
6. Run Prisma validation.

### Task 4: Refactor the iOS foundation

**Files:**
- Create: `project.yml`
- Modify: `ClassTrace/App/**`
- Modify: `ClassTrace/Networking/**`
- Create: `ClassTrace/Domain/**`
- Create: `ClassTrace/Features/**`

**Steps:**
1. Add XcodeGen configuration targeting iOS 17.
2. Replace cloud-function/action transport with REST endpoints.
3. Remove openid and password from client domain models.
4. Introduce repository protocols and dependency injection.
5. Add session restoration and single-flight token refresh.
6. Add static contract tests that can run on Windows.

### Task 5: Build the design system and asset catalog

**Files:**
- Create: `ClassTrace/DesignSystem/**`
- Create: `ClassTrace/Resources/Assets.xcassets/**`
- Create: `docs/design/asset-inventory.md`

**Steps:**
1. Copy approved brand assets from the original mini-program.
2. Prefer SF Symbols for generic actions.
3. Add semantic colors with light/dark variants.
4. Implement reusable button, card, status, empty, loading and error components.
5. Verify 44pt hit targets and Dynamic Type usage by static review.

### Task 6: Implement every functional domain

**Files:**
- Create: `services/api/src/modules/identity/**`
- Create: `services/api/src/modules/classroom/**`
- Create: `services/api/src/modules/hour-ledger/**`
- Create: `ClassTrace/Features/Authentication/**`
- Create: `ClassTrace/Features/Classroom/**`
- Create: `ClassTrace/Features/HourLedger/**`

**Steps:**
1. Implement phone-code and Apple authentication behind provider interfaces.
2. Implement Student, Course, Classroom, Schedule, Session, Hour Ledger and Attendance.
3. Implement Homework, Material, Study Plan, Mistake Book and Points.
4. Implement Notification, Announcement, Feedback and Business Analytics.
5. Implement Teaching Orders, payment records/refunds and StoreKit entitlements.
6. Implement every matching iOS repository, screen and role-specific operation.
7. Add contract, authorization, idempotency and state-transition tests for every domain.

### Task 7: Prove mini-program feature parity

Re-run the inventory against the original 24 cloud functions and every registered page. No domain is deferred by priority. Every operation must have an API route, iOS entry point, loading/empty/error UI, authorization rule, migration mapping and regression evidence.

### Task 8: Release readiness

Add privacy manifest, account deletion, production SMS, Apple sign-in, APNs, StoreKit sandbox, payment-provider webhooks, database backups, observability, App filing notes, App Store review demo account and full migration rehearsal.
