import Foundation

struct Reward: Identifiable, Hashable {
    /// Stable identity (the name) so a selection can be persisted across launches.
    var id: String { name }
    let emoji: String
    let name: String
    let calories: Int
    let description: String
}

let allRewards: [Reward] = [
    Reward(emoji: "🍪", name: "Cookie",          calories: 150, description: "Bakery-fresh"),
    Reward(emoji: "☕", name: "Starbucks Drink",  calories: 250, description: "Venti anything"),
    Reward(emoji: "🧁", name: "Cupcake",          calories: 300, description: "Frosted"),
    Reward(emoji: "🥗", name: "Salad",            calories: 350, description: "Actually good"),
    Reward(emoji: "🍕", name: "Pizza Slice",      calories: 400, description: "NYC-style"),
    Reward(emoji: "🍜", name: "Ramen Bowl",       calories: 500, description: "Tonkotsu"),
    Reward(emoji: "🍔", name: "Burger",           calories: 600, description: "Double patty"),
    Reward(emoji: "🌯", name: "Chipotle Burrito", calories: 980, description: "Full build"),
]
