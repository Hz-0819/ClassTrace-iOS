# ADR-0004: 教学支付与 VIP 分账分域

## Status
Accepted

## Context

教学课费属于教师提供的课程服务；VIP 属于 ClassTrace 提供的数字功能。两者适用不同的履约、退款和平台规则。

## Decision

- 教学套餐默认全额结算给教师，ClassTrace 记录订单、课时履约与协助退款。
- ClassTrace 不维护可提现用户钱包，不自建资金池。
- VIP 使用 StoreKit 2 与服务端 entitlement。
- 教学支付、课时账本、VIP 交易使用独立表与状态机。

## Consequences

### Positive
- 不改变独立教师一次收清课费的现金流习惯。
- 避免将课时余额误当资金余额。
- VIP 可正确处理续订、取消和退款。

### Negative
- 教师已收款后，平台不能承诺无条件垫付退款。
- 需要明确合同、退款规则和争议流程。

