import { HourLedgerService } from "../src/modules/sessions/hour-ledger.service";
import { TokenService } from "../src/modules/identity/token.service";
import { DomainException } from "../src/common/http/domain.exception";

describe("security boundaries", () => {
  it("scopes guardian ledger access to the entry student, not any member of the class", async () => {
    let captured: any;
    const prisma = { hourLedgerEntry: { findMany: jest.fn((query) => { captured = query.where; return []; }) } };
    await new HourLedgerService(prisma as never).list("guardian-1", undefined, undefined, "class-1");
    expect(captured.OR).toContainEqual({ student: { guardians: { some: { guardianUserId: "guardian-1" } } } });
    expect(JSON.stringify(captured)).not.toContain('"members":{"some"');
  });

  it("returns a stable 401 domain error for an invalid refresh token", async () => {
    const prisma = { authSession: { findUnique: jest.fn().mockResolvedValue(null) } };
    await expect(new TokenService(prisma as never).rotate("invalid")).rejects.toMatchObject<Partial<DomainException>>({ code: "INVALID_REFRESH_TOKEN", status: 401 });
  });
});
