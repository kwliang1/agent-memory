---
name: venture-enum-pattern
description: "Venture enum pattern -- T::Enum + Sorbet::EnumerizableEnum + enumerize, not Rails enum macro"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 021ac3c2-b0c1-4819-a048-9574a5a80dda
---

New models in venture must use `T::Enum` with `Sorbet::EnumerizableEnum`, not the Rails `enum` macro:

```ruby
class Status < T::Enum
  include Sorbet::EnumerizableEnum
  enums do
    Pending = new(:pending)
    Active = new(:active)
  end
end
enumerize(:status, in: Status.enumerize_values, value_class: Status)
```

Migration column: `t.string :status` (not integer). Default: `default: 'pending'` (string, not 0).
Reference constants: `Model::Status::Pending` (not `:pending`).
Model typing: `# typed: strict`.
Pattern source: `TreasuryEvent::DeadLetter::Status` and `lib/sorbet/enumerizable_enum.rb`.
