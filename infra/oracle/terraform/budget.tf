# Cost guardrail — we intend to stay 100% Always Free (0 EUR). This budget alerts
# on ANY actual spend so a charge can never go unnoticed (defense for "stay in quota
# while USING the VM", complementing scripts/freetier-guard.py which guards provisioning).

resource "oci_budget_budget" "freetier_guard" {
  compartment_id = var.tenancy_ocid # budgets live in the tenancy root
  amount         = 1                # 1 currency unit; we expect to never spend
  reset_period   = "MONTHLY"
  targets        = [var.tenancy_ocid]
  target_type    = "COMPARTMENT"
  display_name   = "merlin-freetier-guard"
  description    = "Always-Free intent: alert on any spend."
}

# Fires as soon as actual spend reaches 1% of the 1-unit budget (~0.01) — i.e. the
# first cent ever billed.
resource "oci_budget_alert_rule" "any_spend" {
  budget_id      = oci_budget_budget.freetier_guard.id
  type           = "ACTUAL"
  threshold      = 1
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  display_name   = "merlin-any-spend"
  message        = "Oracle charge detected. We should be at 0 EUR (Always Free) — investigate immediately."
}
