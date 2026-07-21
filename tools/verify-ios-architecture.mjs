import { existsSync, readFileSync, readdirSync } from "node:fs";
import { extname, join } from "node:path";

const root = new URL("../", import.meta.url).pathname.replace(/^\/(.:)/, "$1");
const failures = [];

function text(relativePath) {
  return readFileSync(join(root, relativePath), "utf8");
}

function assert(condition, message) {
  if (!condition) failures.push(message);
}

function filesRecursively(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? filesRecursively(path) : [path];
  });
}

assert(existsSync(join(root, "project.yml")), "project.yml is missing");
assert(existsSync(join(root, "ClassTrace/Resources/PrivacyInfo.xcprivacy")), "privacy manifest is missing");
assert(text("project.yml").includes('iOS: "17.0"'), "deployment target must be iOS 17");
assert(!text("ClassTrace/App/ClassTraceApp.swift").includes("preferredColorScheme(.light)"), "app must not force light mode");

const userModel = text("ClassTrace/Domain/Models/APIModels.swift");
for (const forbidden of ["openid", "var password", "appleUserIdentifier", "notificationCredits"]) {
  assert(!userModel.includes(forbidden), `client User model contains forbidden field: ${forbidden}`);
}

const httpClient = text("ClassTrace/Networking/HTTPClient.swift");
assert(httpClient.includes("Idempotency-Key"), "HTTP client must support idempotency keys");
assert(httpClient.includes("x-request-id"), "HTTP client must propagate request ids");
assert(!httpClient.includes("CloudFunction"), "new HTTP client must not know CloudBase function names");

const swiftFiles = filesRecursively(join(root, "ClassTrace")).filter((file) => extname(file) === ".swift");
const swiftSource = swiftFiles.map((file) => readFileSync(file, "utf8")).join("\n");
for (const forbidden of ["CloudFunction", "wx.cloud", "parentOpenId", "teacherOpenId"]) {
  assert(!swiftSource.includes(forbidden), `iOS target still contains legacy coupling: ${forbidden}`);
}
for (const required of [
  "Features/Dashboard/DashboardView.swift",
  "Features/Classroom/ClassroomHubView.swift",
  "Features/Classroom/ClassroomDetailView.swift",
  "Features/Learning/LearningHubView.swift",
  "Features/Profile/ProfileHubView.swift",
  "Domain/Repositories/Repositories.swift"
]) assert(existsSync(join(root, "ClassTrace", required)), `required iOS feature is missing: ${required}`);

const parity = text("docs/architecture/full-parity-matrix.md");
for (const domain of ["身份与用户", "学生与监护关系", "课程、班级与成员", "排课、上课与考勤", "课时账本", "教学内容", "学习管理", "通知、公告与反馈", "账单、支付与退款", "VIP 与系统能力"]) {
  assert(parity.includes(domain), `full parity matrix is missing domain: ${domain}`);
}

const components = text("ClassTrace/DesignSystem/CTComponents.swift");
assert(components.includes("minHeight: 48"), "primary action must meet the 44pt tap target");
assert(components.includes("ContentUnavailableView"), "design system must provide native empty/error states");

const assetRoot = join(root, "ClassTrace/Resources/LegacyImages");
const pngCount = existsSync(assetRoot)
  ? filesRecursively(assetRoot).filter((file) => extname(file).toLowerCase() === ".png").length
  : 0;
assert(pngCount === 72, `expected 72 copied PNG assets, found ${pngCount}`);

if (failures.length) {
  console.error(failures.map((failure) => `FAIL: ${failure}`).join("\n"));
  process.exit(1);
}

console.log(`iOS architecture checks passed (${pngCount} legacy assets inventoried).`);
