import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isLoading: Bool = false
}
