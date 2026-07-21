# ADR-0001: 后端采用模块化单体

## Status
Accepted

## Context

现有小程序由二十余个云函数按 action 分发，边界松散且跨函数规则重复。团队需要快速达到功能对等，同时保证课时、考勤和支付的一致性。

## Decision

使用 TypeScript 模块化单体。领域模块共享单一部署单元和 PostgreSQL，但通过模块公开接口与 outbox 事件协作。

## Consequences

### Positive
- 单事务可以覆盖确认上课与课时扣减。
- 部署、调试和本地测试成本低。
- 领域边界为将来拆分保留条件。

### Negative
- 所有模块仍需一起发布。
- 必须通过代码审查防止跨模块直接访问内部实现。

## Alternatives Considered

- 保留独立云函数：延续现有耦合与事务问题。
- 微服务：当前团队规模和流量不足以抵消运维复杂度。

