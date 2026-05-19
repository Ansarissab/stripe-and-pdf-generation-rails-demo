# Graph Report - .  (2026-05-19)

## Corpus Check
- Corpus is ~48,755 words - fits in a single context window. You may not need a graph.

## Summary
- 564 nodes · 846 edges · 117 communities (56 shown, 61 thin omitted)
- Extraction: 87% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 105 edges (avg confidence: 0.81)
- Token cost: 305,416 input · 76,351 output

## Community Hubs (Navigation)
- [[_COMMUNITY_ActiveAdmin Admin Panel|ActiveAdmin Admin Panel]]
- [[_COMMUNITY_Invoices & Charge History|Invoices & Charge History]]
- [[_COMMUNITY_PDF Drawing Primitives|PDF Drawing Primitives]]
- [[_COMMUNITY_Pundit Authorization|Pundit Authorization]]
- [[_COMMUNITY_Subscriptions Controller|Subscriptions Controller]]
- [[_COMMUNITY_Bin Launchers & CI|Bin Launchers & CI]]
- [[_COMMUNITY_Devise + Pay Auth Stack|Devise + Pay Auth Stack]]
- [[_COMMUNITY_Stripe Runbook & Pitfalls|Stripe Runbook & Pitfalls]]
- [[_COMMUNITY_Schema Migrations & Seeds|Schema Migrations & Seeds]]
- [[_COMMUNITY_Embedded Checkout View|Embedded Checkout View]]
- [[_COMMUNITY_Test Fixtures & Integration|Test Fixtures & Integration]]
- [[_COMMUNITY_Solid Queue Tables|Solid Queue Tables]]
- [[_COMMUNITY_Stripe Elements (Stimulus)|Stripe Elements (Stimulus)]]
- [[_COMMUNITY_Plans Helper|Plans Helper]]
- [[_COMMUNITY_Devise I18n Locales|Devise I18n Locales]]
- [[_COMMUNITY_Production Stack (PumaSolid)|Production Stack (Puma/Solid)]]
- [[_COMMUNITY_Billing Test Fixtures|Billing Test Fixtures]]
- [[_COMMUNITY_Pay Tables Migration|Pay Tables Migration]]
- [[_COMMUNITY_ApplicationController + Pundit Bridge|ApplicationController + Pundit Bridge]]
- [[_COMMUNITY_Home Controller|Home Controller]]
- [[_COMMUNITY_Test Helper Hub|Test Helper Hub]]
- [[_COMMUNITY_AdminUser Trackable Migration|AdminUser Trackable Migration]]
- [[_COMMUNITY_AdminUser Devise Migration|AdminUser Devise Migration]]
- [[_COMMUNITY_User Devise Migration|User Devise Migration]]
- [[_COMMUNITY_User Plan Column Migration|User Plan Column Migration]]
- [[_COMMUNITY_Pay Object Column Migration|Pay Object Column Migration]]
- [[_COMMUNITY_Hotwire Frontend Stack|Hotwire Frontend Stack]]
- [[_COMMUNITY_Pay Gem + Stripe Init|Pay Gem + Stripe Init]]
- [[_COMMUNITY_Generic Policy Tests|Generic Policy Tests]]
- [[_COMMUNITY_application_mailer.rb|application_mailer.rb]]
- [[_COMMUNITY_application_record.rb|application_record.rb]]
- [[_COMMUNITY_locale_policy.rb|locale_policy.rb]]
- [[_COMMUNITY_home_policy.rb|home_policy.rb]]
- [[_COMMUNITY_application_job.rb|application_job.rb]]
- [[_COMMUNITY_AdminSmokeTest|AdminSmokeTest]]
- [[_COMMUNITY_PlanSyncTest|PlanSyncTest]]
- [[_COMMUNITY_UserTest|UserTest]]
- [[_COMMUNITY_BillingTest|BillingTest]]
- [[_COMMUNITY_ApplicationPolicyTest|ApplicationPolicyTest]]
- [[_COMMUNITY_HomePolicyTest|HomePolicyTest]]
- [[_COMMUNITY_LocalePolicyTest|LocalePolicyTest]]
- [[_COMMUNITY_PayChargePolicyTest|Pay::ChargePolicyTest]]
- [[_COMMUNITY_PaySubscriptionPolicyTest|Pay::SubscriptionPolicyTest]]
- [[_COMMUNITY_InvoicePdfTest|InvoicePdfTest]]
- [[_COMMUNITY_InvoicePdfContentTest|InvoicePdfContentTest]]
- [[_COMMUNITY_LocalesControllerTest|LocalesControllerTest]]
- [[_COMMUNITY_HomeControllerTest|HomeControllerTest]]
- [[_COMMUNITY_AccountInvoicesControllerTest|Account::InvoicesControllerTest]]
- [[_COMMUNITY_AccountSubscriptionsControllerTest|Account::SubscriptionsControllerTest]]
- [[_COMMUNITY_AccountSubscriptionsEmbeddedViewTest|AccountSubscriptionsEmbeddedViewTest]]
- [[_COMMUNITY_Application|Application]]
- [[_COMMUNITY_Stimulus Application bootstrap|Stimulus Application bootstrap]]
- [[_COMMUNITY_binthrust launcher|bin/thrust launcher]]
- [[_COMMUNITY_Bullet N+1 Detector|Bullet N+1 Detector]]
- [[_COMMUNITY_AccountInvoicesController|Account::InvoicesController]]
- [[_COMMUNITY_CreateActiveAdminComments migration|CreateActiveAdminComments migration]]
- [[_COMMUNITY_public400.html|public/400.html]]
- [[_COMMUNITY_active_admin.js Sprockets manifest|active_admin.js Sprockets manifest]]
- [[_COMMUNITY_ApplicationHelper|ApplicationHelper]]
- [[_COMMUNITY_ApplicationJob|ApplicationJob]]
- [[_COMMUNITY_ApplicationMailer|ApplicationMailer]]
- [[_COMMUNITY_PWA Service Worker|PWA Service Worker]]
- [[_COMMUNITY_Test Environment Config|Test Environment Config]]
- [[_COMMUNITY_Content Security Policy Initializer (disabled)|Content Security Policy Initializer (disabled)]]
- [[_COMMUNITY_Filter Parameter Logging Initializer|Filter Parameter Logging Initializer]]
- [[_COMMUNITY_Inflections Initializer|Inflections Initializer]]
- [[_COMMUNITY_configrecurring.yml|config/recurring.yml]]
- [[_COMMUNITY_devise_for admin_users|devise_for :admin_users]]
- [[_COMMUNITY_ActiveAdmin.routes|ActiveAdmin.routes]]
- [[_COMMUNITY_devise_for users|devise_for :users]]
- [[_COMMUNITY_mount LetterOpenerWeb (dev)|mount LetterOpenerWeb (dev)]]
- [[_COMMUNITY_GET up rails_health_check|GET /up rails_health_check]]
- [[_COMMUNITY_configstorage.yml|config/storage.yml]]
- [[_COMMUNITY_solid_cache_entries table|solid_cache_entries table]]
- [[_COMMUNITY_solid_queue_recurring_tasks table|solid_queue_recurring_tasks table]]
- [[_COMMUNITY_solid_queue_pauses table|solid_queue_pauses table]]
- [[_COMMUNITY_solid_queue_processes table|solid_queue_processes table]]
- [[_COMMUNITY_solid_queue_semaphores table|solid_queue_semaphores table]]
- [[_COMMUNITY_HomeControllerTest|HomeControllerTest]]
- [[_COMMUNITY_LocalesControllerTest|LocalesControllerTest]]

## God Nodes (most connected - your core abstractions)
1. `t()` - 37 edges
2. `a()` - 24 edges
3. `s()` - 22 edges
4. `c()` - 20 edges
5. `b()` - 19 edges
6. `x()` - 18 edges
7. `g()` - 17 edges
8. `r()` - 17 edges
9. `p()` - 17 edges
10. `Account::SubscriptionsController` - 16 edges

## Surprising Connections (you probably didn't know these)
- `ActiveAdmin AdminUser registration` --semantically_similar_to--> `ActiveAdmin read-only on business data`  [INFERRED] [semantically similar]
  app/admin/admin_users.rb → AGENTS.md
- `Pitfall 9.22 Pay STI scoping in tests` --rationale_for--> `pay_subscriptions table`  [INFERRED]
  docs/stripe_integration/README.md → db/schema.rb
- `InvoicePdf` --implements--> `Pdf base class + 3-tier primitives`  [INFERRED]
  app/pdfs/invoice_pdf.rb → AGENTS.md
- `Sync model: Stripe -> Pay -> users.plan` --rationale_for--> `pay_subscriptions table`  [INFERRED]
  docs/stripe_integration/README.md → db/schema.rb
- `Billing concern on Pay::Customer` --implements--> `Billing concern on Pay::Customer`  [INFERRED]
  app/models/concerns/billing.rb → AGENTS.md

## Hyperedges (group relationships)
- **Per-request locale switching flow** — locales_controller, locale_switching, application_controller, locale_policy [EXTRACTED 0.95]
- **Account subscription lifecycle** — subscriptions_controller, billing_concern, pay_subscription_policy, plans_helper, user_model [EXTRACTED 0.95]
- **ActiveAdmin read-only business resources** — admin_users, admin_pay_customers, admin_pay_subscriptions, admin_pay_charges, concept_admin_readonly [EXTRACTED 0.95]
- **Pundit policy hierarchy (deny-by-default to authenticated to ownership)** — application_policy, authenticated_policy, pay_subscription_policy, pay_charge_policy, home_policy, locale_policy [EXTRACTED 1.00]
- **Embedded Stripe Checkout: server creates incomplete sub, client confirms PaymentIntent** — billing, stripe_elements_controller, stripe_subscription_api, stripe_payment_intent_api [EXTRACTED 0.95]
- **Plan sync on subscription save: PlanSync recomputes User.plan from active Pay::Subscription** — plan_sync, user, pay_subscription_model, billing [EXTRACTED 0.95]
- **CI pipeline composed of rubocop, bundler-audit, importmap audit, brakeman** — bin_rubocop, bin_bundler_audit, bin_importmap, bin_ci [EXTRACTED 1.00]
- **Boot pipeline: bundler -> simplecov(test) -> bootsnap** — bundler_setup, config_simplecov_setup, bootsnap_setup [EXTRACTED 1.00]
- **Rails entrypoint chain: bin/rails -> boot -> application -> environment** — bin_rails, config_boot, config_application, config_environment [EXTRACTED 1.00]
- **Pay/Stripe integration stack** — init_pay, init_pay_customer_billing, init_pay_subscription_sync, concept_pay_gem, concept_stripe [INFERRED 0.95]
- **ActiveAdmin auth + AdminUser scope** — init_active_admin, concept_admin_user, concept_devise, concept_application_controller [INFERRED 0.95]
- **I18n parallel locale parity (en/fr)** — locales_en, locales_fr, locales_devise_en, locales_devise_fr [EXTRACTED 1.00]
- **Pay gem schema cluster** — table_pay_customers, table_pay_subscriptions, table_pay_charges [EXTRACTED 1.00]
- **Solid Queue execution-state tables** — table_solid_queue_jobs, table_solid_queue_ready_executions, table_solid_queue_scheduled_executions [EXTRACTED 1.00]
- **Pay gem migration chain** — migration_create_pay_tables, migration_add_pay_sti_columns, migration_add_object_to_pay_models [EXTRACTED 1.00]
- **PDF generation test suite** — pdf_test_pdftest, invoice_pdf_test_invoicepdftest, invoice_pdf_content_test_invoicepdfcontenttest [INFERRED 0.95]
- **Pundit policy test suite** — application_policy_test_applicationpolicytest, home_policy_test_homepolicytest, locale_policy_test_localepolicytest [INFERRED 0.95]
- **Billing concern + subscriptions controller integration** — billing_test_billingtest, subscriptions_controller_test_accountsubscriptionscontrollertest, plan_sync_test_plansynctest [INFERRED 0.85]
- **Stripe boundary mocking infrastructure** — stripe_stubs_support, billing_fixtures_support, webmock [INFERRED 0.85]
- **Test support modules included into ActiveSupport::TestCase** — stripe_stubs_support, billing_fixtures_support, pdf_text_extraction_support [EXTRACTED 0.95]
- **SimpleCov + WebMock + parallel testing harness** — simplecov, webmock, parallel_testing [EXTRACTED 0.95]

## Communities (117 total, 61 thin omitted)

### Community 0 - "ActiveAdmin Admin Panel"
Cohesion: 0.05
Nodes (58): ActiveAdmin AdminUser registration, ActiveAdmin Dashboard page, ActiveAdmin Pay::Charge registration, ActiveAdmin Pay::Customer registration, ActiveAdmin Pay::Subscription registration, AdminUser model, ActiveAdmin User registration, ApplicationController (+50 more)

### Community 1 - "Invoices & Charge History"
Cohesion: 0.05
Nodes (11): Account::InvoicesController, derived_plan_for(), sync_user_plan(), CreateActiveAdminComments, DropActiveAdminComments, AdminUser, InvoicePdf, Pdf (+3 more)

### Community 2 - "PDF Drawing Primitives"
Cohesion: 0.22
Nodes (52): _(), a(), ae(), b(), be(), c(), ce(), d() (+44 more)

### Community 3 - "Pundit Authorization"
Cohesion: 0.07
Nodes (7): User, Pay::ChargePolicy, Scope, Pay::SubscriptionPolicy, ApplicationPolicy, Scope, AuthenticatedPolicy

### Community 4 - "Subscriptions Controller"
Cohesion: 0.09
Nodes (10): Account::SubscriptionsController, active_subscription(), current_subscription(), extract_client_secret(), open_billing_portal(), start_embedded_subscription(), start_hosted_checkout(), swap_plan() (+2 more)

### Community 5 - "Bin Launchers & CI"
Cohesion: 0.08
Nodes (29): active_admin:build_css rake task, bin/bundler-audit launcher, bin/ci launcher, bin/dev Foreman launcher, bin/docker-entrypoint, bin/importmap launcher, bin/jobs SolidQueue runner, bin/kamal launcher (+21 more)

### Community 6 - "Devise + Pay Auth Stack"
Cohesion: 0.08
Nodes (30): ActiveAdmin Gem, AdminUser Devise Scope, ApplicationController, LocaleSwitching Concern, Pay::Charge Model, Pay::Subscription Model, PlanSync Concern, Pundit Authorization (+22 more)

### Community 7 - "Stripe Runbook & Pitfalls"
Cohesion: 0.09
Nodes (24): Account::SubscriptionsController, Environment variables, Local development loop, Operations: orphan subs, resync, flush, Pitfall 9.23 cancel POST stub needs cancel_at, Pitfall 9.7 Invoice#payment_intent breaking change, Pitfall 9.22 Pay STI scoping in tests, Pitfall 9.12 PlanSync clobbers active sub (+16 more)

### Community 8 - "Schema Migrations & Seeds"
Cohesion: 0.28
Nodes (15): AddObjectToPayModels migration, AddPayStiColumns migration, AddPlanToUsers migration, AddTrackableAndLockableToAdminUsers migration, CreatePayTables migration, DeviseCreateAdminUsers migration, DeviseCreateUsers migration, admin_users table (+7 more)

### Community 9 - "Embedded Checkout View"
Cohesion: 0.16
Nodes (14): AdminUser, ApplicationRecord, Billing (concern), Stimulus Controllers Index, account/subscriptions/embedded.html.slim, AccountSubscriptionsEmbeddedViewTest, HelloController (Stimulus), Pay::Subscription (gem) (+6 more)

### Community 10 - "Test Fixtures & Integration"
Cohesion: 0.2
Nodes (11): AdminSmokeTest, admin_users fixture, BillingTest, InvoicePdfContentTest, InvoicePdfTest, Account::InvoicesControllerTest, PdfTest, PlanSyncTest (+3 more)

### Community 12 - "Solid Queue Tables"
Cohesion: 0.25
Nodes (8): clear_solid_queue_finished_jobs recurring task, solid_queue_blocked_executions table, solid_queue_claimed_executions table, solid_queue_failed_executions table, solid_queue_jobs table, solid_queue_ready_executions table, solid_queue_recurring_executions table, solid_queue_scheduled_executions table

### Community 13 - "Stripe Elements (Stimulus)"
Cohesion: 0.6
Nodes (5): #clearError(), connect(), #ensureStripeJs(), #showError(), #submit()

### Community 14 - "Plans Helper"
Cohesion: 0.47
Nodes (4): plan_badge(), plan_label(), plan_price_cents(), plan_price_label()

### Community 15 - "Devise I18n Locales"
Cohesion: 0.33
Nodes (6): Devise Gem, Devise Initializer, Devise Locale (English), Devise Locale (French), Locale namespace: devise (view extensions), Locale namespace: devise view extensions (fr)

### Community 16 - "Production Stack (Puma/Solid)"
Cohesion: 0.33
Nodes (6): Puma Web Server, Solid Cache Store, Solid Queue Background Jobs, Puma Server Config, Solid Queue Config, Production Environment Config

### Community 28 - "Hotwire Frontend Stack"
Cohesion: 0.67
Nodes (3): Hotwire Turbo Rails, Hotwire Stimulus, Importmap Pins

### Community 29 - "Pay Gem + Stripe Init"
Cohesion: 0.67
Nodes (3): Pay Gem, Stripe Payment Processor, Pay Gem Initializer

### Community 30 - "Generic Policy Tests"
Cohesion: 0.67
Nodes (3): ApplicationPolicyTest, HomePolicyTest, LocalePolicyTest

## Ambiguous Edges - Review These
- `ApplicationPolicy` → `bin/brakeman (binstub)`  [AMBIGUOUS]
  bin/brakeman · relation: references

## Knowledge Gaps
- **129 isolated node(s):** `ApplicationMailer`, `ApplicationRecord`, `LocalePolicy`, `HomePolicy`, `ApplicationJob` (+124 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **61 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `ApplicationPolicy` and `bin/brakeman (binstub)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `t()` connect `PDF Drawing Primitives` to `Invoices & Charge History`, `ApplicationController + Pundit Bridge`, `Subscriptions Controller`, `Plans Helper`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `docs/stripe_integration/README.md` connect `Stripe Runbook & Pitfalls` to `ActiveAdmin Admin Panel`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Are the 16 inferred relationships involving `t()` (e.g. with `.draw()` and `.table_columns()`) actually correct?**
  _`t()` has 16 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ApplicationMailer`, `ApplicationRecord`, `LocalePolicy` to the rest of the system?**
  _129 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ActiveAdmin Admin Panel` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Invoices & Charge History` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._