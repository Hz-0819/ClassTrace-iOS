export type AttendanceDecision = {
  status: "SCHEDULED" | "PRESENT" | "LEAVE" | "ABSENT" | "INSUFFICIENT";
  deductHours: number;
  nextRemainingHours: number;
};

export function decideAttendance(input: {
  billingMode: "PREPAID" | "CASH";
  status: AttendanceDecision["status"];
  requestedHours?: number;
  plannedHours: number;
  remainingHours: number;
}): AttendanceDecision {
  if (input.status !== "PRESENT" || input.billingMode === "CASH") {
    return { status: input.status, deductHours: 0, nextRemainingHours: input.remainingHours };
  }
  const deductHours = input.requestedHours ?? input.plannedHours;
  if (!Number.isFinite(deductHours) || deductHours <= 0) throw new Error("INVALID_DEDUCTION");
  if (input.remainingHours < deductHours) {
    return { status: "INSUFFICIENT", deductHours: 0, nextRemainingHours: input.remainingHours };
  }
  return { status: "PRESENT", deductHours, nextRemainingHours: input.remainingHours - deductHours };
}

export function reverseConsumption(currentRemaining: number, consumedDelta: number) {
  if (consumedDelta >= 0) throw new Error("NOT_A_CONSUMPTION");
  const restored = -consumedDelta;
  return { restored, nextRemainingHours: currentRemaining + restored };
}
