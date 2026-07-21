# ADR-0003: 使用平台无关身份

## Status
Accepted

## Context

旧系统同时使用 openid、userId、teacherId、parentId，iOS 又需要 Apple 和手机号登录。

## Decision

`users.id` 是唯一业务身份。登录凭证保存在 `user_identities`，支持 phone、apple、wechat；角色保存在 `user_roles`。

## Consequences

### Positive
- iOS、微信和未来 Web/Android 共享账号。
- 一个用户可同时拥有教师和家长角色。
- openid 不再扩散到业务表。

### Negative
- 旧用户需要账号关联与冲突处理流程。

