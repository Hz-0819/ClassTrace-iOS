# ADR-0002: PostgreSQL 作为业务事实库

## Status
Accepted

## Context

班级、成员、课节、考勤、课时流水、订单和权益之间存在强关系与事务要求。现有文档数据库模型存在身份和成员双轨。

## Decision

新系统使用 PostgreSQL。JSONB 仅用于低频扩展字段，不用来替代核心关系。

## Consequences

### Positive
- ACID 事务保障确认上课、退款和课时调整。
- 唯一约束、外键与检查约束保护数据一致性。
- 报表和对账查询更直接。

### Negative
- 需要显式迁移旧集合数据。
- Schema 变更需要版本化 migration。

## Alternatives Considered

- 继续使用 CloudBase 文档数据库：迁移快，但难以彻底解决关系与事务问题。

