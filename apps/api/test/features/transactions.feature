Feature: Submitting Transactions to the Childchain

  Scenario: Submitting a Deposit Transaciton
    Given I submit a deposit transaction
    Then the transaction should be rejected
    And say "cannot submit a deposit transaction"

  Scenario: Transaction contains missing input UTXOs
    Given I submit a transaction
    And it contains a missing input UTXO
    Then I should reject the transaction
    And say "the input is missing"

  Scenario: Transaction contains spent input UTXOs
    Given I submit a transaction
    And it contains a spent UTXO
    Then I should reject the transaction
    And say "the input is spent"

  Scenario: Transaction input and output amounts do not match
    Given I submit a transaction
    And the amounts do not match
    Then I should reject the transaction
    And say "the input and output amount do not match"

  Scenario: Transactions return an ID to confirm the status
    Given I submit a vali transaction
    Then I should accept the transaction
