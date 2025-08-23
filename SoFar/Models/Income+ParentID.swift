import Foundation
import CoreData

extension Income {
    /// Optional parent identifier linking a recurrence series.
    @NSManaged public var parentID: UUID?
}
