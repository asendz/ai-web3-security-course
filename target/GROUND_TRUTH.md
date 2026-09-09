# SecondSwap — Ground Truth (Answer Key)

Source: the public [Code4rena SecondSwap report](https://code4rena.com/reports/2024-12-secondswap) (Dec 2024), used here as ground truth for measuring recall. 3 High and 20 Medium severity findings.

The "One-line root cause" column is a fast index, not the full picture - when it doesn't settle a match on its own, check the full description below (or follow the "Full report" link for the complete original writeup, including proof-of-concept code), or read the actual `.sol` source in `target/src/`.

## High (3)

| ID | Severity | Title | One-line root cause | Full report |
|----|----------|-------|---------------------|--------------|
| H-01 | High | Vesting listing order affects claimable amounts | Shared `stepsClaimed` state in VestingManager is inherited across listings, so ordering changes how much is claimable. | [link](https://code4rena.com/reports/2024-12-secondswap#h-01-secondswap_marketplace-vesting-listing-order-affects-how-much-the-vesting-buyers-can-claim-at-a-given-step) |
| H-02 | High | `transferVesting` creates incorrect vesting for buyers | `stepsClaimed` stays constant across sales, letting new buyers unlock tokens prematurely. | [link](https://code4rena.com/reports/2024-12-secondswap#h-02-transfervesting-creates-an-incorrect-vesting-for-new-users-when-they-purchase-a-vesting-because-stepsclaimed-is-the-same-for-all-sales-allowing-an-attacker-to-prematurely-unlock-too-many-tokens) |
| H-03 | High | Incorrect `releaseRate` in `transferVesting` | Release-rate calc ignores already-claimed amounts, so users unlock more tokens than were locked. | [link](https://code4rena.com/reports/2024-12-secondswap#h-03-in-transfervesting-the-grantorvestingreleaserate-is-calculated-incorrectly-which-leads-to-the-sender-being-able-to-unlock-more-tokens-than-were-initially-locked) |

## Medium (20)

| ID | Severity | Title | One-line root cause | Full report |
|----|----------|-------|---------------------|--------------|
| M-01 | Medium | Inverted listing-type validation | Uses `!=` instead of `==`, bypassing minimum-purchase enforcement for PARTIAL listings. | [link](https://code4rena.com/reports/2024-12-secondswap#m-01-incorrect-listing-type-validation-bypasses-enforcement-of-minimum-purchase-amount) |
| M-02 | Medium | Discounted listings unpurchasable | Rounding when computing `baseAmount` at the reduced price blocks purchase of discounted listings. | [link](https://code4rena.com/reports/2024-12-secondswap#m-02-listing-potential-can-not-be-purchased-with-discounted-price) |
| M-03 | Medium | No way to remove a supported token | Missing removal from `isTokenSupport` leaves funds at risk if a whitelisted stablecoin depegs. | [link](https://code4rena.com/reports/2024-12-secondswap#m-03-missing-option-to-remove-tokens-from-the-istokensupport-mapping-can-result-in-huge-financial-loss-for-users-and-the-protocol) |
| M-04 | Medium | Token-owner mapping collision | One vesting creator can affect others' plans when multiple creators share the same token. | [link](https://code4rena.com/reports/2024-12-secondswap#m-04-creator-of-one-vesting-plan-can-affect-vesting-plans-created-by-other-users) |
| M-05 | Medium | Payment-token decimals limit price granularity | Decimal precision prevents listings cheaper than 0.000001 USDT for low-value tokens. | [link](https://code4rena.com/reports/2024-12-secondswap#m-05-price-granularity-limited-by-payment-token-decimals-cannot-list-tokens-cheaper-than-0000001-usdt) |
| M-06 | Medium | `stepsClaimed` underflow blocks claims | Rounding can push `stepsClaimed > numOfSteps`, causing underflow that reverts `claim`. | [link](https://code4rena.com/reports/2024-12-secondswap#m-06-underflow-in-claimable-dosing-claim-function) |
| M-07 | Medium | Platform fee mutable after listing | Fees can change post-listing, so buyers/sellers can't know exact costs upfront. | [link](https://code4rena.com/reports/2024-12-secondswap#m-07-buyfee-and-sellfee-should-be-known-before-purchase) |
| M-08 | Medium | Stale penalty fee on delisting | Early-delisting penalty uses outdated values if fees change between listing and delisting. | [link](https://code4rena.com/reports/2024-12-secondswap#m-08-outdated-penalty-fee-gets-charged-if-the-penalty-fee-has-changed-since-listing) |
| M-09 | Medium | Reallocation bypass via listing | Users can block reallocation by listing vestings to the marketplace, evading protocol controls. | [link](https://code4rena.com/reports/2024-12-secondswap#m-09-users-can-prevent-being-reallocated-by-listing-to-marketplace) |
| M-10 | Medium | Vested tokens transferable via marketplace | Already-vested tokens can be moved away from users through the marketplace mechanism. | [link](https://code4rena.com/reports/2024-12-secondswap#m-10-tokens-that-have-already-been-vested-can-be-transferred-from-a-user) |
| M-11 | Medium | `maxSellPercent` bypass over time | The sell-percent cap is bypassed by selling previously purchased vestings later. | [link](https://code4rena.com/reports/2024-12-secondswap#m-11-maxsellpercent-can-be-buypassed-by-selling-previously-bought-vestings-at-a-later-time) |
| M-12 | Medium | Unauthorized `maxSellPercent` increase | Improper validation allows unauthorized increases to `maxSellPercent`. | [link](https://code4rena.com/reports/2024-12-secondswap#m-12-unauthorized-increase-of-maxsellpercent) |
| M-13 | Medium | Marketplace address change loses listings | Changing the VestingManager marketplace address orphans previous marketplace listings. | [link](https://code4rena.com/reports/2024-12-secondswap#m-13-marketplace-change-in-vesting-manager-leads-to-loss-of-previous-marketplace-listing) |
| M-14 | Medium | Incorrect referral fee math | Referral fee calculations produce mathematically incorrect amounts. | [link](https://code4rena.com/reports/2024-12-secondswap#m-14-incorrect-referral-fee-calculations) |
| M-15 | Medium | Missing sellability check in `completePurchase` | No sellability check lets unsellable-but-previously-listed tokens be bought. | [link](https://code4rena.com/reports/2024-12-secondswap#m-15-missing-sellable-check-in-completepurchase-will-cause-a-user-to-buy-a-token-marked-as-unsellable-by-s2admin-if-it-was-listed-beforehand) |
| M-16 | Medium | DoS on vest transfer | Insufficient validation enables a denial-of-service when transferring vests. | [link](https://code4rena.com/reports/2024-12-secondswap#m-16-possible-dos-scenario-when-transferring-vests-to-another-address) |
| M-17 | Medium | Uneven vesting from `stepDuration` rounding | Rounding in `stepDuration` produces uneven vesting distributions. | [link](https://code4rena.com/reports/2024-12-secondswap#m-17-rounding-error-in-stepduration-calculations) |
| M-18 | Medium | Unlisting after extra claims locks tokens | Unlisting after additional claims locks tokens that should remain claimable. | [link](https://code4rena.com/reports/2024-12-secondswap#m-18-unlisting-a-vesting-after-seller-has-claimed-additional-steps-locks-tokens-which-should-have-been-claimable-already) |
| M-19 | Medium | Large step counts cause fund loss | Very large step counts can cause fund loss or uneven distribution to beneficiaries. | [link](https://code4rena.com/reports/2024-12-secondswap#m-19-large-number-of-steps-in-a-vesting-may-lead-to-loss-of-beneficiary-funds-or-uneven-vesting-distribution) |
| M-20 | Medium | `maxSellPercent` breaks on delist after claim | The sell-percent cap breaks when delisting after the seller claims additional steps. | [link](https://code4rena.com/reports/2024-12-secondswap#m-20-maxsellpercent-will-be-broken-when-a-vesting-is-delisted-after-a-seller-has-claimed-additional-steps) |

## Full descriptions

Distilled from the original report - impact + recommended mitigation, code-reference snippets kept, full PoC code and submitter credit lists dropped (see "Full report" links above for those).

### H-01 - Vesting listing order affects claimable amounts

When a vesting is listed, the vesting is transferred to the `SecondSwap_VestingManager` contract. With no previous listings, the contract “inherits” the `stepsClaimed` from the listed vesting:

https://github.com/code-423n4/2024-12-secondswap/blob/main/contracts/SecondSwap_StepVesting.sol#L288-L290

```solidity
@>        if (_vestings[_beneficiary].totalAmount == 0) {
            _vestings[_beneficiary] = Vesting({
@>            stepsClaimed: _stepsClaimed,
            ...
```

Suppose the `stepsClaimed` amount is positive. In that case, further listing allocations will be mixed with the previous one, meaning the “inherited” `stepsClaimed` amount will be present in the listings transferred from the `SecondSwap_VestingManager` contract to users with no allocation that buy listings through `SecondSwap_Marketplace::spotPurchase`.

This condition creates two scenarios that affect how much the user can claim:

Assuming for both scenarios that there are no listings yet for a given vesting plan.

Scenario 1:

- First listing has no `claimedSteps`
- Second listing has `claimedSteps`

Since the first listing has no `claimedSteps`, users with no previous vestings allocation can buy any of the listings and their listing won’t have claimed steps, allowing them to claim immediately after their purchase.

Scenario 2:

- First listing has `claimedSteps`
- Second listing has no claimedSteps

Due to the first listing having a positive `claimedSteps` amount, users with no previous vesting allocations will have their vestings inherit the `claimedSteps`, meaning they won’t be able to claim if they are on the current step corresponding to `claimedSteps`.

**Recommended mitigation:** Add a virtual total amount to the manager contract on each vesting plan deployed.

**TechticalRAM (SecondSwap) confirmed**

### H-02 - `transferVesting` creates incorrect vesting for buyers

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingManager.sol#L139

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L232

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L288-L295

If a user sells their vesting on the marketplace, it will be transferred with `transferVesting` to the address of the VestingManager (see first GitHub-Link).

This means that all tokens sold are stored on the address of the VestingManager in the StepVesting contract. However, it is possible that all these sold vestings have different numbers of `stepsClaimed`. The problem is that the vesting of the VestingManager always stores only one value for `stepsClaimed`, which is the one taken from the first vesting that is sold.

After that, `stepsClaimed` cannot change because the `VestingManager` cannot claim. Only when the `totalAmount` of the vesting reaches 0, meaning when everything has been sold and there are no more listings, will a new value for `stepsClaimed` be set at the next listing. If a new user who doesn’t have a vesting yet buys one, they would adopt the wrong value for `stepsClaimed` (see second and third GitHub links).

It is quite likely that `stepsClaimed` is 0, as probably something was sold right at the beginning and the value hasn’t changed since then. This then leads to the user being able to directly claim a part of the tokens without waiting.

**Recommended mitigation:** A mapping should be created where the stepsClaimed for each listing are stored so that they can be transferred correctly to the buyer.

**TechticalRAM (SecondSwap) confirmed**

### H-03 - Incorrect `releaseRate` in `transferVesting`

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L230

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L178-L182

Users can sell their vestings on the marketplace. For this, the portion of the vesting that a user wants to sell is transferred to the address of the vesting contract until another user purchases the vesting.

Since this alters the seller’s vesting, the `releaseRate` must be recalculated. Currently, it is calculated as follows:

`grantorVesting.releaseRate = grantorVesting.totalAmount / numOfSteps;`.

The problem here is that it does not take into account how much of the `grantorVesting.totalAmount` has already been claimed. This means that the releaseRate ends up allowing the user to claim some of the tokens already claimed again.

It is important that the claiming of the stolen rewards must be done before the complete locking period ends, because otherwise the claimable function will only give the user the tokens they have not yet claimed (see second GitHub link). This would not work, as the attacker has already claimed everything by that point and the bug just works when `releaseRate` is used to calculate rewards.

This bug could also cause some users who were legitimately waiting for their tokens to no longer receive any, as they have been stolen and are now unavailable. It could also violate the invariant that no more than the maxSellPercent is ever sold, as this bug could allow an attacker to unlock more than the maxSellPercent.

**Recommended mitigation:** When calculating the release rate for the seller, the steps already claimed and the amount already claimed should be taken into account:
`grantorVesting.releaseRate = (grantorVesting.totalAmount - grantorVesting.amountClaimed) /(numOfSteps -grantorVesting.stepsClaimed);`

**calvinx (SecondSwap) confirmed**

### M-01 - Inverted listing-type validation

https://github.com/code-423n4/2024-12-secondswap/blob/main/contracts/SecondSwap_Marketplace.sol#L253

Incorrect validation of the listing type allows bypassing the enforcement of `_minPurchaseAmt` being within the range of `0` to `_amount`.

**Recommended mitigation:** The validation logic should be updated as follows:

https://github.com/code-423n4/2024-12-secondswap/blob/main/contracts/SecondSwap_Marketplace.sol#L253

### M-02 - Discounted listings unpurchasable

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_Marketplace.sol#L459-L471

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_Marketplace.sol#L413-L422

In the function `SecondSwap_Marketplace::spotPurchase()`, depending on the listing’s discount type, the price is computed accordingly:

And then the `baseAmount` that the buyer needs to pay is calculated from the discounted price. Although there is a check to enforce listing value is not too small with the original price, but it still can be too small with the discounted price because indeed the discounted price is lower than the original price. So in that case, the buyer won’t be able to purchase listed sale.

Example with a simple vulnerable path:

- Alice lists vesting with `amount = 1e15` (assume the token has `18` decimals), currency is `USDT`, `price = 1200` ($0.0012), with fixed discount = 20% and the listing type is Single.
- Bob tries to purchase Alice’s sale, but the transaction fails because `baseAmount` is 0 in this case: `baseAmount = 1e15 * 1200 * 80% / 1e18 = 0`.

Impacts:

- Users are potentially unable to purchase discounted vestings

**Recommended mitigation:** Consider updating the check for `baseAmount` in function `listVesting()` to take discount into account.

**TechticalRAM (SecondSwap) confirmed**

### M-03 - No way to remove a supported token

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_Marketplace.sol#L205-L218

Because there is no option for the admin to remove a token from the `isTokenSupport` mapping, a depeg of a whitelisted token can lead to significant financial loss for users and the protocol.

**Recommended mitigation:** Add an option for the admin to remove currencies from the whitelist. This way, no new listings can be created with a depegged currency. To protect the vestings already listed with the bad currency, make sure to check if the currency used for a listing is still on the whitelist before executing a sale. This way, sellers of the impacted listings are protected from selling their vestings for worthless currency and can delist their listings once they become aware of the depeg.

### M-04 - Token-owner mapping collision

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingDeployer.sol#L141-L144

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingDeployer.sol#L176-L183

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingDeployer.sol#L218-L231

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingDeployer.sol#L193-L206

Vesting plans are created by token issuers in the `VestingDeployer` contract. When a vesting plan is created, a new StepVesting contract is deployed.

SecondSwap_VestingDeployer.sol#L119-L129

```solidity
address newVesting = address(
    new SecondSwap_StepVesting(
        msg.sender,
        manager,
        IERC20(tokenAddress),
        startTime,
        endTime,
        steps,
        address(this)
    )
);
```

This contract address will be used by token issuers to manage their vesting plans. However, currently it’s possible that a creator of one vesting plan can affect vesting plans created by other users.

Token issuers are set by the admin in the `setTokenOwner()` function.

SecondSwap_VestingDeployer.sol#L141-L144

```solidity
function setTokenOwner(address token, address _owner) external onlyAdmin {
    require(
        _tokenOwner[_owner] == address(0),
        "SS_VestingDeployer: Existing token have owner"
    );
    _tokenOwner[_owner] = token;
}
```

As can be seen, it’s possible for a token to have multiple owners, as the mapping used is `owner => token` instead of `token => owner`. Now if one token has multiple owners and there are 2 vesting plans, creator of vesting plan A can influence vesting plan B and vice versa.

`createVesting()` and `createVestings()` functions check that token that is linked to the msg.sender is the same as the token of the vesting plan, which in this case will be true regardless of the fact that msg.sender is not the creator of said vesting plan.

SecondSwap_VestingDeployer.sol#L176-L183

```solidity
require(
    _tokenOwner[msg.sender] ==
        address(SecondSwap_StepVesting(_stepVesting).token()),
    "SS_VestingDeployer: caller is not the token owner"
);
```

But when `_createVesting()` function of the StepVesting contract will be invoked, it will transfer funds not from the msg.sender but from the actual creator of the vesting plan.

SecondSwap_StepVesting.sol#L306-L308

```solidity
if (!_isInternal) {
    token.safeTransferFrom(tokenIssuer, address(this), _totalAmount);
}
```

`transferVesting()` function is also vulnerable to that issue because it uses the same check as `createVesting()`.

SecondSwap_VestingDeployer.sol#L218-L228

```solidity
function transferVesting(
    address _grantor,
    address _beneficiary,
    uint256 _amount,
    address _stepVesting,
    string memory _transactionId
) external {
    require(
        _tokenOwner[msg.sender] ==
            address(SecondSwap_StepVesting(_stepVesting).token()),
        "SS_VestingDeployer: caller is not the token owner"
    );
```

**Recommended mitigation:** Store the address of the vesting plan’s creator in a `mapping(address vestingPlan => address creator)` and check if the msg.sender is the actual creator of the vesting plan.

### M-05 - Payment-token decimals limit price granularity

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_Marketplace.sol#L256

The SecondSwap marketplace enforces a minimum price floor based on the payment token’s smallest unit which will commonly be USDT. This creates a limitation where tokens cannot be listed for less than 0.000001 USDT (or equivalent smallest unit of other 6 decimal payment tokens).

Root Cause:

- `pricePerUnit` must be greater than 0
- `pricePerUnit` represents price in payment token’s smallest units for 1 vesting token.
- For USDT (6 decimals), minimum `pricePerUnit` is 1 (0.000001 USDT)
- Prices lower than this cannot be represented

Impact:

- Cannot list very low-value tokens at their true market price
- Could prevent legitimate trading of extremely low-value tokens

This limitation will be particularly impactful as memecoins with such low values are fairly common.

### M-06 - `stepsClaimed` underflow blocks claims

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L172-L181

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L196-L199

A user who buys vesting tokens after fully claiming their allocation at the end of the vesting period will be unable to claim the newly acquired tokens.

in some cases due to rounding issues the
- `stepsClaimed > numOfSteps`

In `claimable` function `claimableSteps` is calculated as follow:

```solidity
174:@>       uint256 claimableSteps = currentStep - vesting.stepsClaimed;
```

For that the user cannot claim newly purchased amounts.

**Recommended mitigation:** Apply the following correction to the `claimable` function:

### M-07 - Platform fee mutable after listing

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_Marketplace.sol#L240

The platform allows the `buyFee` and `sellFee` parameters for a vesting plan to be modified after a listing is created. This creates a significant issue in terms of transparency and predictability for users engaging in transactions.

**Recommended mitigation:** Consider two additional parameters to be added for the listing:

Also make the changes to the `Listing` struct and `spotPurchase` to use the correct fees.

### M-08 - Stale penalty fee on delisting

https://github.com/code-423n4/2024-12-secondswap/blob/main/contracts/SecondSwap_Marketplace.sol#L360

Minimum listing duration is currently set at 2 mins, at which point a listing cancellation will no longer incur the fee when unlisted less than 2 minutes since it got listed. However, users can be charged an outdated fee which is more or less the initial fee they expected to pay.

**Recommended mitigation:** Having a cache of the fee stored in the listing struct of the listing ID would be sufficient to figure out which fee to charge them.

### M-09 - Reallocation bypass via listing

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L216-L235

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingManager.sol#L139

The token issuer has the ability to change vesting allocation. However, a user can prevent his vesting from being allocated by listing his vesting to the marketplace.

The function `SecondSwap_StepVesting::transferVesting()` can be used by token issuer to transfer vesting, effectively reallocating vestings. By listing the vesting to marketplace, seller’s allocated amount is sent to `VestingManager` contract, which can make the token issuer unable to reallocate his vesting directly (due to available amount check). Indeed, if the token issuer decides to reallocate that wanted amount from `VestingManager`, then this can cause the marketplace to be insolvent.

Note that: This attack vector can be done by front-running, since the codebase is deployed to Ethereum.

Impacts:

- Token issuer can not reallocate as expected. At least, the total allocated amount can not be reallocated, depending on the max sell percent.

**Recommended mitigation:** Consider adding trusted role to unlist from marketplace, so that the reallocation can be handled completely.

### M-10 - Vested tokens transferable via marketplace

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L216-L235

As stated by the contest page, token issuer must be able to reallocate vesting allocations from one user to another. It can be done via `transferVesting()` function of the `StepVesting` contract.

SecondSwap_StepVesting.sol#L224-L232

```solidity
require(
    grantorVesting.totalAmount - grantorVesting.amountClaimed >=
        _amount,
    "SS_StepVesting: insufficient balance"
);
grantorVesting.totalAmount -= _amount;
grantorVesting.releaseRate = grantorVesting.totalAmount / numOfSteps;
_createVesting(
    _beneficiary,
    _amount,
    grantorVesting.stepsClaimed,
    true
);
```

As can be seen, the function ensures that amount transferred is not greater than amount of tokens to vest left after some of them have been claimed.

However, it does not account for tokens that have already been vested, but remain unclaimed by a user. The moment tokens are vested, they cease to be part of the vesting process because the conditions for their release have already been met. Vested but unclaimed tokens are effectively owned by the beneficiary, but remain unclaimed. This essentially allows token issuer to transfer tokens owned by the user instead of reallocation a part of the vesting schedule.

**Recommended mitigation:** `transferVesting()` should account for tokens that have already been vested but remain unclaimed.

### M-11 - `maxSellPercent` bypass over time

https://github.com/code-423n4/2024-12-secondswap/blob/b9497bcf5100046a169276cb6b351ebc0eddc2cc/contracts/SecondSwap_VestingManager.sol#L127-L134

Because the `maxSellPercent` can be bypassed by selling previously bought vestings at a later time, the core functionality to limit the amount of unvested tokens which can be sold is broken.

**Recommended mitigation:** To prevent more locked tokens to be sellable than specified in ´maxSellPercent´ consider adding a `stepsBought` to the Allocation struct to be able to adjust the `bought` value according to the steps already claimed by the user:

The `stepsBought` value would be adjusted each time a user buys or sells a vesting and would be set to the current `stepsClaimed` value of the buyer. In addition, for sells, the bought amount would also need to be reduced by the already claimed amount.

Buy a vesting:

- Buyer buys 100 tokens and the `stepsBought` value is set to his current `stepsClaimed` value. This way we know for which steps the bought value will be claimable. e.g `stepsBought` is 5 => bought value was allocated to step 6 to 10

Sell a vesting:

- Buyer claims 2 more periods and wants to sell tokens
- The `bought` part of the `sellLimit` is determined by calculating the `bought` amount for each step and reducing the original `bought`amount by the steps already claimed:

For this to work:

- The `bought` amount must be reduced to the calculated sellLimit
- We need to sell `bought` allocations first before selling own allocations. Therefore the `bought` amount must be reduced by the amount which should be sold. Only when the `bought` amount reaches 0, the `sold` amount should be increased.

The result would be that the sold amount represents only the amount a user sold of his initial allocation.
In addition the `Allocation` struct also needs a `stepsSold` variable which can be used to adjust/reduce the `sold` amount according to the claimed steps of the seller/buyer.

**TechticalRAM (SecondSwap) confirmed**

### M-12 - Unauthorized `maxSellPercent` increase

https://github.com/code-423n4/2024-12-secondswap/blob/b9497bcf5100046a169276cb6b351ebc0eddc2cc/contracts/SecondSwap_VestingManager.sol#L194-L198

https://github.com/code-423n4/2024-12-secondswap/blob/b9497bcf5100046a169276cb6b351ebc0eddc2cc/contracts/SecondSwap_VestingManager.sol#L179

This issue allows the `maxSellPercent` to be increased to 20% against the will of the token issuer. This will result in users being able to sell tokens even when the issuer intended to prevent selling.

**Recommended mitigation:** To mitigate this issue, a new variable `initiated` should be added to the vesting settings. This variable will track whether the vesting has been initialized. The `setSellable` function should only update the `maxSellPercent` if `initiated` is false which should only be when the vesting is initial created.

**bobwong (SecondSwap) confirmed**

### M-13 - Marketplace address change loses listings

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingManager.sol#L204

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingManager.sol#L121

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingManager.sol#L149

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingManager.sol#L161

When interacting with the `MarketPlace` contract and vesting listings, the `MarketPlace` contract calls the `VestingManager` contract (using the address gotten from the `MarketplaceSetting` contract) which calls the `StepVesting` contract itself to transfer vestings from one address to another.

The `VestingManager` contract contains the `setMarketplace` function which is in place in case the `MarketPlace` contract needs to be changed and redeployed instead of an upgrade (upgrades to the MarketPlace contract occur through the proxy admin, so this function is to change the proxy entirely). When a new MarketPlace contract is set, all previous listings in the marketplace remain stuck, unlistable or inaccessible by the user who listed them, leading to loss of vested assets, simply because the VestingManager is no longer connected to that instance of the marketplace.

**Recommended mitigation:** Provide a way to allow after a change in the marketplace contract, the user to be able to remove their vested listings and transfer it back to their address from the previous marketplace.

### M-14 - Incorrect referral fee math

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_Marketplace.sol#L480-#L483

When a purchase of listed tokens is performed, the caller can provide a `referral` address. This address should receive a referral fee as a reward for introducing users to the project. According to the dev team, the referral payment will be done off-chain.

However, in the current implementation, the `referralFeeCost` calculations are incorrect, which results in much higher fees (ou to 90% of `buyersFeeTotal`) for the referral than expected.

**Recommended mitigation:** The `referralFeeCost` should be calculated as a percentage of `buyerFeeTotal`.

The correct calculation should be:

This will result in `referralFee = 2.5e6` (exactly 10% of `buyerFeeTotal`)

### M-15 - Missing sellability check in `completePurchase`

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingManager.sol#L167-L186

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_VestingManager.sol#L161-L164

A token marked sellable can be purchased because of the absence of the sellable check when completing a spot purchase.

**Recommended mitigation:** Add a sellable check in the completePurchase function has done in the listVesting function

**TechticalRAM (SecondSwap) confirmed**

### M-16 - DoS on vest transfer

https://github.com/code-423n4/2024-12-secondswap/blob/main/contracts/SecondSwap_StepVesting.sol#L225

Vestings can be transferred to another address by a trusted authority. All the necessary parameters are recalculated like the `totalAmount` & `releaseRate` for the current owner for the vesting.

However it is possible that a call to transfer the vesting might be frontrun where the owner of the original vesting claims their token resulting in an overall revert.

**Recommended mitigation:** A way would be to pause claiming of tokens when transferring to avoid this issue & unpause later.

### M-17 - Uneven vesting from `stepDuration` rounding

https://github.com/code-423n4/2024-12-secondswap/blob/214849c3517eb26b31fe194bceae65cb0f52d2c0/contracts/SecondSwap_StepVesting.sol#L133

When deploying a vesting plan, token issuer can specify the end time of the schedule and number of steps over which tokens should be released. `StepVesting` calculates the duration of each distinctive step by dividing the duration of the schedule by number of steps.

SecondSwap_StepVesting.sol#L131-L133

```solidity
endTime = _endTime;
numOfSteps = _numOfSteps;
stepDuration = (_endTime - _startTime) / _numOfSteps;
```

However, currently it’s possible for calculations to round down, which could lead to multiple problems.

First, consider a scenario where calculations of `stepDuration` round down to 0. This will result in inability to claim funds from the `StepVesting` contract. In order to claim tokens from the vesting schedule, a user must call `claim()` function of the contract, which in turn will call `claimable()` to get the amount of tokens currently available for claim.

SecondSwap_StepVesting.sol#L193-L194

```solidity
function claim() external {
    (uint256 claimableAmount, uint256 claimableSteps) = claimable(
        msg.sender
    );
```

When `claimable()` is invoked, it will try to calculate current step by dividing elapsed time by duration of the step, which will revert as solidity does not support division by 0.

SecondSwap_StepVesting.sol#L173

```solidity
uint256 currentStep = elapsedTime / stepDuration;
```

Secondly, because of the rounding, it’s possible that vesting will be completed earlier than the schedule. Consider a 3 month vesting plan which equals 7884000 seconds and the number of steps is 1*000*000. The step duration will be calculated as `7884000 / 1000000 = 7.884`, which will round down to 7. Now the actual time it will take to complete the schedule is `7 * 1000000 = 7000000` seconds, which is 81 days, meaning that vesting is completed roughly 10 days earlier than the schedule.

**Recommended mitigation:** When calculating `stepDuration` revert when `_endTime - _startTime` is not perfectly divisible by `_numOfSteps`.

### M-18 - Unlisting after extra claims locks tokens

https://github.com/code-423n4/2024-12-secondswap/blob/b9497bcf5100046a169276cb6b351ebc0eddc2cc/contracts/SecondSwap_VestingManager.sol#L149-L152

Because unlisted vestings are equally distributed to the unclaimed steps of the seller, if a seller unlists a vesting after he claimed additional steps, tokens which should have been claimable already are locked again and the unlocking schedule is disrupted.

**Recommended mitigation:** To prevent locking tokens which should be claimable when a vesting is unlisted, consider adding the `lastStepsClaimedSeller` variable listing info indicating the last step the seller has claimed when creating the listing:

Also, an additional info about claimable tokens should be added to the vesting information:

When the seller unlists a vesting, his last `stepsClaimed` is compared to `lastStepsClaimedSeller` of the listing. If they differ, they are handled like this:

An amount of refunded tokens proportional to the steps claimed since the vesting was listed are allocated to `claimableAmount` of the seller and can be claimed immediately since they have been unlocked already:

`claimableAmount = refundedTokens * (`stepsClaimed`-`lastStepsClaimedSeller`) / numOfSteps`

`releaseRate` of the seller is adjusted using the remaining refunded tokens.

### M-19 - Large step counts cause fund loss

https://github.com/code-423n4/2024-12-secondswap/blob/main/contracts/SecondSwap_StepVesting.sol#L298

Some token owners may create StepVesting contracts with very large numbers of steps, to simulate a continous vesting. This can lead to two edge cases for the releaseRate of a beneficiary:

- Consider a scenario where a vesting is created that has less tokens than there are number of steps in the plan. Then the releaseRate would be calculated to 0, so users will essentially lose their vestings. The severity of this would depend on how many steps there are and how much the vesting is. Suppose there are 100000000 steps in a vesting plan with duration 1 year. A user receives a vesting for 90e6 USDC. So the releaseRate will be calculated as 90e6/100000000 = 0.9, which is rounded down to 0. So the user will lose his tokens.
- This can also lead to a situation where the release rate becomes 1 and a large amount of the tokens get vested at the very last step, creating a very uneven vesting distribution. A requirement is that the number of steps is more than tokenAmount/2. So if the amount of steps is say 10000000 USDC or 10e6 USDC, the number of steps has to be more than 5e6 USDC for the bug to occur. So likelihood is very low.

This is only a real concern with tokens that have very low decimals, which are in scope as per the competition page.

Protocol function is impacted as beneficiaries will not get their liquidity released correctly, so their funds will essentially be temporarily locked.

**Recommended mitigation:** Mitigation is non-trivial as it would require partially changing protocol design - instead of calculating release rate, calculate release amount based on how many steps are passed in the `claimable()` function.

### M-20 - `maxSellPercent` breaks on delist after claim

https://github.com/code-423n4/2024-12-secondswap/blob/b9497bcf5100046a169276cb6b351ebc0eddc2cc/contracts/SecondSwap_VestingManager.sol#L149-L152

https://github.com/code-423n4/2024-12-secondswap/blob/b9497bcf5100046a169276cb6b351ebc0eddc2cc/contracts/SecondSwap_VestingManager.sol#L130-L134

When a listed vesting is delisted after the seller has claimed additional steps, the full listed amount is deducted from the `sold` value of the seller’s `Allocation` data. This allows him to sell tokens which should have already been unlocked and claimable which breaks a core functionality of the protocol, namely the sell limit intended by the value set for `maxSellPercent`.

**Recommended mitigation:** To prevent sellers being able to sell more tokens than specified in ´maxSellPercent´ after unlisting a vesting, consider adding a `stepsClaimedSeller` vriable to the `Listing` struct indicating the last step the seller has claimed when he created the listing:

In addition, the variable `amountClaimable` needs to be added to the `Vesting` struct:

Once the seller unlists a listing, the value of `stepsClaimedSeller` is compared to the seller’s current `stepsClaimed`. If the seller has claimed additional steps since he initially listed the vesting, the number of steps is calculated and a proportional amount of the refunded tokens is added to `amountClaimable` making them claimable instantly:

`amountToAdd = refundedAmount * (stepsClaimed – stepsClaimedSeller) / totalSteps`

To ensure the calculation of `available` tokens stays accurate, the same amount needs to be added to `amountClaimed`.

The remaining amount of refunded tokens is deducted from the sold amount and is available for sale again.

When claiming tokens the amount saved in `amountClaimable` is added to the amount transfered to the user and `amountClaimable` is set to 0.
