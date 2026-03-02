import Foundation

struct CloudSyncTestRecord: Identifiable, Equatable {
    let id: UUID
    let text: String
    let updatedAt: Date
    let imageData: Data?
}
