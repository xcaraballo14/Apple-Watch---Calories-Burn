import Foundation

struct Reward: Identifiable, Hashable, Codable {
    /// Stable identity (the name) so a selection can be persisted across launches.
    var id: String { name }
    let emoji: String
    let name: String
    let calories: Int
    let description: String
}

let allRewards: [Reward] = [
    Reward(emoji: "🍪", name: "Chocolate Chip Cookie", calories: 150, description: "Bakery-fresh"),
    Reward(emoji: "🌮", name: "Taco",                  calories: 180, description: "Hard or soft"),
    Reward(emoji: "🍦", name: "Ice Cream Cone",        calories: 230, description: "Single scoop"),
    Reward(emoji: "🥤", name: "Soda (20 oz)",          calories: 240, description: "Ice cold"),
    Reward(emoji: "🍫", name: "Brownie",               calories: 250, description: "Fudgy center"),
    Reward(emoji: "🍩", name: "Donut",                 calories: 270, description: "Glazed"),
    Reward(emoji: "🧁", name: "Cupcake",               calories: 300, description: "Frosted"),
    Reward(emoji: "🧋", name: "Bubble Tea (Boba)",     calories: 330, description: "Milk tea + pearls"),
    Reward(emoji: "🍟", name: "French Fries",          calories: 365, description: "Crispy & salted"),
    Reward(emoji: "🥐", name: "Cinnamon Roll",         calories: 380, description: "Warm & gooey"),
    Reward(emoji: "☕", name: "Starbucks Frappuccino", calories: 390, description: "Blended"),
    Reward(emoji: "🍕", name: "Pizza Slice",           calories: 400, description: "NYC-style"),
    Reward(emoji: "🧀", name: "Mac & Cheese Bowl",     calories: 420, description: "Extra creamy"),
    Reward(emoji: "🍗", name: "Chicken Wings",         calories: 440, description: "6 pieces"),
    Reward(emoji: "🥪", name: "Chicken Sandwich",      calories: 490, description: "Crispy"),
    Reward(emoji: "🍜", name: "Ramen Bowl",            calories: 500, description: "Tonkotsu"),
    Reward(emoji: "🥛", name: "Milkshake",             calories: 530, description: "Thick & creamy"),
    Reward(emoji: "🍔", name: "Cheeseburger",          calories: 550, description: "Double patty"),
    Reward(emoji: "🌽", name: "Nachos",                calories: 590, description: "Fully loaded"),
    Reward(emoji: "🌯", name: "Chipotle Burrito",      calories: 980, description: "Full build"),
]
