import Foundation
import Observation
import StoreKit

@MainActor @Observable
final class StoreKitManager {
    private(set) var products: [Product] = []
    private(set) var isWorking = false
    var errorMessage: String?
    private let productIDs = ["com.classtrace.vip.monthly", "com.classtrace.vip.yearly"]

    func load() async {
        do { products = try await Product.products(for: productIDs).sorted { $0.price < $1.price } }
        catch { errorMessage = error.localizedDescription }
    }

    func purchase(_ product: Product, repository: ClassTraceRepository, userId: String) async -> Bool {
        isWorking = true; defer { isWorking = false }
        do {
            guard let accountToken = UUID(uuidString: userId) else { throw StoreKitError.invalidAccount }
            switch try await product.purchase(options: [.appAccountToken(accountToken)]) {
            case let .success(verification):
                let transaction = try verified(verification)
                _ = try await repository.verifyStoreKit(signedTransaction: verification.jwsRepresentation)
                await transaction.finish()
                return true
            case .pending, .userCancelled: return false
            @unknown default: return false
            }
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func restore(repository: ClassTraceRepository) async -> Bool {
        isWorking = true; defer { isWorking = false }
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                let transaction = try verified(result)
                _ = try await repository.verifyStoreKit(signedTransaction: result.jwsRepresentation)
                await transaction.finish()
            }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        guard case let .verified(value) = result else { throw StoreKitError.failedVerification }
        return value
    }
}

private enum StoreKitError: LocalizedError {
    case failedVerification, invalidAccount
    var errorDescription: String? { self == .invalidAccount ? "账号标识无效" : "App Store 交易验证失败" }
}
