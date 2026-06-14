# Optional cost guard: a 0-spend budget alert. Created only if you provide a
# billing_account id (Cloud Billing Budget API must be enabled).
data "google_billing_account" "acct" {
  count           = var.billing_account != "" ? 1 : 0
  billing_account = var.billing_account
}

resource "google_billing_budget" "freetier_guard" {
  count           = var.billing_account != "" ? 1 : 0
  billing_account = var.billing_account
  display_name    = "merlin-freetier-guard"

  amount {
    specified_amount {
      currency_code = "EUR"
      units         = 1
    }
  }

  threshold_rules {
    threshold_percent = 0.01 # ~first cent
    spend_basis       = "CURRENT_SPEND"
  }

  dynamic "all_updates_rule" {
    for_each = var.budget_alert_email != "" ? [1] : []
    content {
      # email via a Monitoring notification channel you create, or use Pub/Sub.
      # Left minimal: budget still shows in console + default billing-admin emails.
      disable_default_iam_recipients = false
    }
  }
}
