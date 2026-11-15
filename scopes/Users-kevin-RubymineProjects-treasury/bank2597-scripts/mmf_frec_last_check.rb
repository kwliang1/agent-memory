# Read-only: latest balance-check record (Frec totalEquity vs treasury) per MMF account, plus provider ids.
require 'json'
ids = AccountProvider::MoneyMarketFund.pluck(:customer_account_id).compact.uniq
rows = CustomerAccount.where(id: ids).order(:id).map do |ca|
  prov = ca.money_market_fund_provider
  subs = SubAccount.where(account: ca)
  rec = BalanceCheck::Record.where(sub_account_id: subs.select(:id)).order(checked_at: :desc).first
  { ca: ca.id, provider_account_id: prov&.try(:provider_account_id).present?, subs: subs.map { |s| [s.id, s.try(:status) || (s.closed_at ? 'closed' : 'open')] },
    last_check: rec&.checked_at&.to_date&.to_s, frec_cents: rec&.external_amount_cents, treasury_cents: rec&.treasury_amount_cents,
    nonzero_frec_ever: BalanceCheck::Record.where(sub_account_id: subs.select(:id)).where.not(external_amount_cents: 0).maximum(:checked_at)&.to_date&.to_s }
end
puts 'JSON_START'; puts JSON.generate(rows); puts 'JSON_END'
