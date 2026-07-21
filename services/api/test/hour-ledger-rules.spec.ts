import { decideAttendance, reverseConsumption } from "../src/modules/sessions/hour-ledger.rules";

describe("hour ledger rules", () => {
  it("deducts prepaid attendance exactly once from the supplied balance", () => {
    expect(decideAttendance({ billingMode: "PREPAID", status: "PRESENT", plannedHours: 1, remainingHours: 10 }))
      .toEqual({ status: "PRESENT", deductHours: 1, nextRemainingHours: 9 });
  });

  it("marks insufficient balance without producing a negative balance", () => {
    expect(decideAttendance({ billingMode: "PREPAID", status: "PRESENT", requestedHours: 1.5, plannedHours: 1, remainingHours: 1 }))
      .toEqual({ status: "INSUFFICIENT", deductHours: 0, nextRemainingHours: 1 });
  });

  it("records cash and absence attendance without changing prepaid hours", () => {
    expect(decideAttendance({ billingMode: "CASH", status: "PRESENT", plannedHours: 1, remainingHours: 3 }).deductHours).toBe(0);
    expect(decideAttendance({ billingMode: "PREPAID", status: "LEAVE", plannedHours: 1, remainingHours: 3 }).nextRemainingHours).toBe(3);
  });

  it("undoes consumption with a positive compensating amount", () => {
    expect(reverseConsumption(9, -1)).toEqual({ restored: 1, nextRemainingHours: 10 });
  });
});
