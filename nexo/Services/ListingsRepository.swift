import Foundation
import Combine
import Supabase


@MainActor
final class ListingsRepository: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let client = SupabaseClientProvider.shared.client

    func fetchAvailable() async {
        isLoading = true
        defer { isLoading = false }
        do {
            listings = try await client
                .from("listings")
                .select()
                .eq("status", value: "available")
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            lastError = "No pudimos cargar disponibilidades."
            print("[Supabase] fetchAvailable error:", error)
        }
    }

    func publish(_ new: NewListing) async -> Bool {
        do {
            try await client
                .from("listings")
                .insert(new)
                .execute()
            await fetchAvailable()
            return true
        } catch {
            lastError = "No pudimos publicar."
            print("[Supabase] publish error:", error)
            return false
        }
    }
}
