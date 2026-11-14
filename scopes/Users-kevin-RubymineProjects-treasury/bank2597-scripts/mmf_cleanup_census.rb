# Read-only. Every MMF CustomerAccount: activity, position, and every Interchange onboarding gap
# (mirrors MoneyMarketFund::Adapters::Interchange on main as of 2026-11-09, but lists all gaps, not the first).
require 'json'

A = MoneyMarketFund::Adapters::Interchange
WINDOW = 90.days.ago

def err(e) = "#{e.class.name.demodulize}: #{e.message[0, 140]}"

def first_error
  yield
  nil
rescue StandardError => e
  err(e)
end

def address_gaps(addr, who)
  return ["#{who} no address"] if addr.nil?

  g = []
  g << "#{who} address country #{addr.country.inspect}" if addr.country != 'US'
  g << "#{who} invalid ZIP #{addr.postal_code.inspect}" if !A::ZIP_DIGITS.match?(addr.postal_code.to_s.delete('^0-9'))
  g << "#{who} no street" if addr.street1.blank?
  g << "#{who} no city" if addr.city.blank?
  g << "#{who} bad state #{addr.state.inspect}" if !A::US_STATE_CODE.match?(addr.state.to_s.strip.upcase)
  g
end

def person_gaps(p)
  return ['control person missing'] if p.nil?

  id = p.person_identity_data
  g = []
  g << "control person is #{p.entity_type}" if p.entity_type.to_s != 'PERSON'
  g << 'control person no name' if id.first_name.blank? || id.last_name.blank?
  g << 'control person no phone' if id.phone.blank?
  g << 'control person no DOB' if id.birthdate.nil?
  g << 'control person no SSN' if !A::SSN_DIGITS.match?(id.ssn.to_s.delete('^0-9'))
  g.concat(address_gaps(id.current_address, 'control person'))
  g << 'control person not KYC-verified' if Entities::StatusService.verified?(p) != true
  g
rescue StandardError => e
  ["control person error #{err(e)}"]
end

def org_gaps(owner_ca, app)
  id = owner_ca.owner_identity_data
  g = []
  g << "unsupported incorporation type #{id.incorporation_type.inspect}" if A::ENTITY_TYPES[id.incorporation_type.to_s].nil?
  g << 'single-member LLC' if id.incorporation_type.to_s == 'LLC' && id.disregarded
  g << "formed in #{id.incorporation_country}" if id.incorporation_country.present? && id.incorporation_country != 'US'
  g << "bad formation state #{id.incorporation_state.inspect}" if id.incorporation_state.present? && !A::US_STATE_CODE.match?(id.incorporation_state.to_s.strip.upcase)
  g << 'no entity name' if id.name.blank?
  g << 'no EIN' if !A::EIN_DIGITS.match?(id.tax_id.to_s.delete('^0-9'))
  g.concat(address_gaps(id.current_address, 'fund'))
  g << 'W-9 uncertified' if !(app.w9_entity_certify_us_person_for_tax && app.w9_entity_certify_entered_information_correctly)
  g << 'W-9 no backup-withholding answer' if app.w9_entity_certify_not_subject_to_backup_withholding.nil?
  g << "W-9 payee code #{app.w9_entity_exempt_payee_code.inspect}" if first_error { A.send(:exempt_payee_code, app.w9_entity_exempt_payee_code) }
  g << (app.authorized_signer_is_us_citizen.nil? ? 'signer citizenship blank' : 'signer not US citizen') if !app.authorized_signer_is_us_citizen
  g << 'fund not KYB-verified' if Entities::StatusService.verified?(owner_ca.owner) != true
  g
rescue StandardError => e
  ["org error #{err(e)}"]
end

ids = (AccountProvider::MoneyMarketFund.pluck(:customer_account_id) +
  Applications::MoneyMarketFund.where.not(money_market_fund_account_id: nil).pluck(:money_market_fund_account_id) +
  InvestmentVehicleConfiguration.where.not(money_market_fund_account_id: nil).pluck(:money_market_fund_account_id)).compact.uniq

rows = CustomerAccount.where(id: ids).order(:id).map do |ca|
  buys = MoneyMarketFund::Buy.where(customer_account_id: ca.id)
  sells = MoneyMarketFund::Sell.where(customer_account_id: ca.id)
  yields = MoneyMarketFund::Yield.where(customer_account_id: ca.id)
  app = Applications::MoneyMarketFund.where(money_market_fund_account_id: ca.id).order(:id).last
  owner_ca = CustomerAccount.where(owner_entity_api_id: ca.owner_entity_api_id).where.not(id: ca.id).first || ca
  row = {
    ca: ca.id,
    uuid: ca.uuid,
    closed: ca.try(:closed_at).present?,
    provider: (ca.money_market_fund_provider&.provider&.serialize rescue nil),
    app: app&.id,
    app_state: app&.state,
    app_cp_set: app&.control_person_entity_api_id.present?,
    buys: buys.count, sells: sells.count, yields: yields.count,
    buys_90d: buys.where('created_at > ?', WINDOW).count,
    sells_90d: sells.where('created_at > ?', WINDOW).count,
    yields_90d: yields.where('accrued_on > ?', WINDOW).count,
    last_buy: buys.maximum(:created_at)&.to_date&.to_s,
    last_sell: sells.maximum(:created_at)&.to_date&.to_s,
    last_yield: yields.maximum(:accrued_on)&.to_date&.to_s,
  }
  row[:pos] = begin
    MoneyMarketFundAccounts::BalanceService.position_balance(customer_account: ca).to_f
  rescue StandardError => e
    "err #{err(e)}"
  end
  begin
    row[:name] = owner_ca.owner_identity_data&.name
  rescue StandardError => e
    row[:name] = "err #{err(e)}"
  end
  if app.nil?
    row[:gaps] = ['no application']
    next row
  end

  cp = begin
    if app.control_person_entity_api_id.present?
      row[:cp_source] = 'application'
      Applications::MoneyMarketFunds::InfoService.control_person(application: app)
    else
      row[:cp_source] = 'fund lead (proxy)'
      CustomerAccounts::Entities::InfoService.resolve_fund_lead(owner_ca).effective
    end
  rescue StandardError => e
    row[:cp_error] = err(e)
    nil
  end
  row[:cp_name] = cp && [cp.identity_data.try(:first_name), cp.identity_data.try(:last_name)].compact.join(' ')
  row[:gaps] = org_gaps(owner_ca, app) + person_gaps(cp)
  row[:adapter_individual] = cp && first_error { A.send(:individual, cp, owner_ca, app) }
  row[:adapter_org] = first_error { A.send(:organization, owner_ca, app, 'x' * 22) }
  row
end

puts 'JSON_START'
puts JSON.generate(rows)
puts 'JSON_END'
