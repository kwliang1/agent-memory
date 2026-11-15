# Read-only: treasury cash + position vs Frec totalEquity for every MMF CustomerAccount.
require 'json'
ids = AccountProvider::MoneyMarketFund.pluck(:customer_account_id).compact.uniq
rows = CustomerAccount.where(id: ids).order(:id).map do |ca|
  r = { ca: ca.id }
  r[:cash] = (ca.cash_balance.to_f rescue "err #{$!.class}: #{$!.message[0, 80]}")
  r[:pos] = (MoneyMarketFundAccounts::BalanceService.position_balance(customer_account: ca).to_f rescue "err #{$!.class}")
  r[:frec] = (MoneyMarketFund::Adapters::Base.for(ca).external_total_equity.to_f rescue "err #{$!.class}: #{$!.message[0, 120]}")
  r
end
puts 'JSON_START'
puts JSON.generate(rows)
puts 'JSON_END'
