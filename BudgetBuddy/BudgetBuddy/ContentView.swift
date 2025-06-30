import SwiftUI

@main
struct BudgetBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

// MARK: - ViewModel

class BudgetData: ObservableObject {
    @Published var income: Double = 0
    @Published var foodBudget: Double = 0 {
        didSet { validateBudgets() }
    }
    @Published var rentBudget: Double = 0 {
        didSet { validateBudgets() }
    }
    @Published var travelBudget: Double = 0 {
        didSet { validateBudgets() }
    }
    @Published var customBudgets: [String: Double] = [:] {
        didSet { validateBudgets() }
    }
    @Published var expenses: [Expense] = []
    @Published var goals: [Goal] = []
    @Published var overIncomeLimit: Bool = false

    var totalBudget: Double {
        foodBudget + rentBudget + travelBudget + customBudgets.values.reduce(0, +)
    }

    var totalExpense: Double {
        expenses.map { $0.amount }.reduce(0, +)
    }

    var availableBudget: Double {
        totalBudget - goals.map { $0.savedAmount }.reduce(0, +)
    }

    var isOverBudget: Bool {
        totalExpense > availableBudget
    }

    func addExpense(_ expense: Expense) {
        expenses.append(expense)
    }

    func addGoal(_ goal: Goal) {
        goals.append(goal)
    }

    func categoryBudget(for category: String) -> Double {
        switch category {
        case "Food": return foodBudget
        case "Rent": return rentBudget
        case "Travel": return travelBudget
        default: return customBudgets[category] ?? 0
        }
    }

    func totalSpent(in category: String) -> Double {
        expenses.filter { $0.category == category }.map { $0.amount }.reduce(0, +)
    }

    func isOverBudget(for category: String) -> Bool {
        totalSpent(in: category) > categoryBudget(for: category)
    }

    func validateBudgets() {
        let predefinedTotal = foodBudget + rentBudget + travelBudget
        if predefinedTotal > income {
            let scale = income / predefinedTotal
            foodBudget *= scale
            rentBudget *= scale
            travelBudget *= scale
        }
        overIncomeLimit = totalBudget > income
    }
}

struct Expense: Identifiable {
    let id = UUID()
    var title: String
    var amount: Double
    var category: String
}

struct Goal: Identifiable {
    let id = UUID()
    var name: String
    var targetAmount: Double
    var savedAmount: Double
}

// MARK: - MainView

struct MainView: View {
    @StateObject var budgetData = BudgetData()

    var body: some View {
        TabView {
            BudgetPlannerView()
                .tabItem { Label("Budget", systemImage: "creditcard") }
                .environmentObject(budgetData)

            ExpensesView()
                .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle") }
                .environmentObject(budgetData)

            GoalsView()
                .tabItem { Label("Goals", systemImage: "target") }
                .environmentObject(budgetData)

            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
        }
    }
}

// MARK: - BudgetPlannerView

struct BudgetPlannerView: View {
    @EnvironmentObject var budgetData: BudgetData
    @State private var newCustomCategory: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Monthly Income")) {
                    TextField("Enter income", value: $budgetData.income, format: .number)
                        .keyboardType(.decimalPad)
                }

                Section(header: Text("Predefined Budgets")) {
                    BudgetSliderView(title: "Food", value: $budgetData.foodBudget)
                    BudgetSliderView(title: "Rent", value: $budgetData.rentBudget)
                    BudgetSliderView(title: "Travel", value: $budgetData.travelBudget)
                }

                Section(header: Text("Custom Budgets")) {
                    ForEach(Array(budgetData.customBudgets.keys), id: \.self) { key in
                        HStack {
                            Text(key)
                            Slider(value: Binding(
                                get: { budgetData.customBudgets[key] ?? 0 },
                                set: {
                                    let current = budgetData.customBudgets[key] ?? 0
                                    let remaining = budgetData.income - (budgetData.totalBudget - current)
                                    budgetData.customBudgets[key] = min($0, max(0, remaining))
                                }
                            ), in: 0...50000, step: 100)
                            Text("₹\(Int(budgetData.customBudgets[key] ?? 0))")
                                .frame(width: 80, alignment: .trailing)
                        }
                    }

                    HStack {
                        TextField("Add Custom Category", text: $newCustomCategory)
                        Button("Add") {
                            let trimmed = newCustomCategory.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && budgetData.customBudgets[trimmed] == nil {
                                budgetData.customBudgets[trimmed] = 0
                                newCustomCategory = ""
                            }
                        }
                    }
                }

                Section(header: Text("Summary")) {
                    Text("Total Budget: ₹\(Int(budgetData.totalBudget))")
                    Text("Total Expenses: ₹\(Int(budgetData.totalExpense))")
                    Text("Available Budget After Goals: ₹\(Int(budgetData.availableBudget))")

                    if budgetData.overIncomeLimit {
                        Text("⚠️ Total budget exceeds income!")
                            .foregroundColor(.red)
                    }
                    if budgetData.isOverBudget {
                        Text("⚠️ You are over total budget!")
                            .foregroundColor(.red)
                    }

                    ForEach(["Food", "Rent", "Travel"] + Array(budgetData.customBudgets.keys), id: \.self) { category in
                        if budgetData.isOverBudget(for: category) {
                            Text("⚠️ \(category) category over budget!")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Budget Planner")
        }
    }
}

struct BudgetSliderView: View {
    var title: String
    @Binding var value: Double
    @EnvironmentObject var budgetData: BudgetData

    var maxValue: Double {
        let current = value
        let other = budgetData.foodBudget + budgetData.rentBudget + budgetData.travelBudget - current
        return max(0, budgetData.income - other)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(title): ₹\(Int(value))")
            Slider(value: Binding(
                get: { value },
                set: { newValue in
                    value = min(newValue, maxValue)
                    budgetData.validateBudgets()
                }
            ), in: 0...50000, step: 100)
        }
    }
}

// MARK: - ExpensesView

struct ExpensesView: View {
    @EnvironmentObject var budgetData: BudgetData
    @State private var title = ""
    @State private var amount: Double = 0
    @State private var category = "Food"
    var categories: [String] {
        ["Food", "Rent", "Travel"] + Array(budgetData.customBudgets.keys)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Expense")) {
                    TextField("Title", text: $title)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }

                    Button("Add") {
                        guard !title.isEmpty, amount > 0 else { return }
                        budgetData.addExpense(Expense(title: title, amount: amount, category: category))
                        title = ""
                        amount = 0
                        category = "Food"
                    }
                }

                Section(header: Text("Expenses")) {
                    ForEach(budgetData.expenses) { expense in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(expense.title)
                                Text(expense.category).font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Text("₹\(Int(expense.amount))")
                        }
                    }
                }
            }
            .navigationTitle("Expenses")
        }
    }
}

// MARK: - GoalsView

struct GoalsView: View {
    @EnvironmentObject var budgetData: BudgetData
    @State private var name = ""
    @State private var targetAmount: Double = 0
    @State private var savedAmount: Double = 0

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Goal")) {
                    TextField("Goal Name", text: $name)
                    TextField("Target Amount", value: $targetAmount, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Saved Amount", value: $savedAmount, format: .number)
                        .keyboardType(.decimalPad)

                    Button("Add Goal") {
                        guard !name.isEmpty, targetAmount > 0 else { return }
                        budgetData.addGoal(Goal(name: name, targetAmount: targetAmount, savedAmount: savedAmount))
                        name = ""
                        targetAmount = 0
                        savedAmount = 0
                    }
                }

                Section(header: Text("Goals")) {
                    ForEach(budgetData.goals) { goal in
                        VStack(alignment: .leading) {
                            Text(goal.name)
                            ProgressView(value: goal.savedAmount, total: goal.targetAmount)
                            HStack {
                                Text("Saved: ₹\(Int(goal.savedAmount))")
                                Spacer()
                                Text("Target: ₹\(Int(goal.targetAmount))")
                            }.font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Goals")
        }
    }
}

// MARK: - LearnView

struct LearnView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Budgeting Tips")) {
                    Text("1. Track your income and expenses.")
                    Text("2. Allocate budgets to categories wisely.")
                    Text("3. Set savings goals.")
                    Text("4. Avoid overspending.")
                    Text("5. Review budgets monthly.")
                }
            }
            .navigationTitle("Learn")
        }
    }
}
