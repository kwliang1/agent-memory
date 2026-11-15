# Read-only: addresses on an FBO account's entities, Belltower's address, and the fund address for every funded MMF account.
def fmt(e)
  a = e&.identity_data&.current_address
  a ? [a.street1, a.street2, a.city, a.state, a.postal_code, a.country].compact.join(', ') : 'NONE'
rescue StandardError => ex
  "err #{ex.class}"
end

def ename(e)
  e.identity_data.try(:name).presence || [e.identity_data.try(:first_name), e.identity_data.try(:last_name)].join(' ')
end

bt = EntityAPI::Entity.find(TreasuryPrime::AccountApplications::InfoService::BELLTOWER_ENTITY_ID)
puts "BELLTOWER #{bt.identity_data.name} | #{fmt(bt)}"

[205674].each do |id|
  ca = CustomerAccount.find(id)
  puts "CA #{id} owner=#{ca.owner_entity_api_id} source=#{ca.source} name=#{ca.owner_identity_data.name} | own address #{fmt(ca.owner)}"
  ents = begin
    CustomerAccounts::Entities::InfoService.entities(ca)
  rescue StandardError => ex
    puts "  entities err #{ex.class}: #{ex.message[0, 150]}"
    CustomerAccounts::Entities::InfoService.related_ipseity_entities(ca.owner)
  end
  ents.each do |role, list|
    Array(list).compact.each { |e| puts "  #{role} | #{e.id} | #{ename(e)} | #{fmt(e)}" }
  end
end

puts 'FUNDED MMF ACCOUNTS'
ids = AccountProvider::MoneyMarketFund.pluck(:customer_account_id)
CustomerAccount.where(id: ids).each do |mmf|
  next if MoneyMarketFundAccounts::BalanceService.position_balance(customer_account: mmf).to_f < 1

  o = CustomerAccount.where(owner_entity_api_id: mmf.owner_entity_api_id).where.not(id: mmf.id).first || mmf
  puts "#{mmf.id} | owner_ca #{o.id} | src #{o.source} | fbo #{o.fbo?} | #{o.owner_identity_data.name} | #{fmt(o.owner)}"
end
