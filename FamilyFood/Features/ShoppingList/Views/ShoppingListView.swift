import SwiftUI
import SwiftData

/// Einkaufsliste. Mirrors the current week's plan: the "Gerichte" cards are the planned
/// recipes (minus any removed here), and the "Zutaten" checklist is their ingredients aggregated.
/// All logic lives in `ShoppingListViewModel`; this is presentation + wiring only.
struct ShoppingListView: View {
    @StateObject private var viewModel = ShoppingListViewModel()
    @Query private var recipes: [RecipeModel]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FFScreenHeader(title: "Einkaufsliste") {
                    FFHeaderIconButton(systemImage: "trash",
                                       accessibilityLabel: "Liste leeren",
                                       isEnabled: !viewModel.displayedRecipes.isEmpty,
                                       action: viewModel.clearAll)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.s32) {
                        gerichteSection
                        if !viewModel.items.isEmpty { zutatenSection }
                    }
                    // Full width, so the empty state stays on the 24pt axle instead of centring.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, AppTheme.Spacing.s8)
                    .padding(.bottom, AppTheme.Spacing.s24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { viewModel.refresh(recipes: recipes) }
            .onChange(of: recipes) { _, updated in viewModel.refresh(recipes: updated) }
        }
    }

    // MARK: - Gerichte

    private var gerichteSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s16) {
            Text("Gerichte in der Einkaufsliste")
                .appText(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.s24)

            if viewModel.displayedRecipes.isEmpty {
                Text("Noch keine Gerichte. Plane Rezepte im Wochenplan – sie landen automatisch hier.")
                    .appText(.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppTheme.Spacing.s24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.s12) {
                        ForEach(viewModel.displayedRecipes) { recipe in
                            RecipeShoppingCard(recipe: recipe) { viewModel.removeRecipe(recipe.id) }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.s24)
                }
            }
        }
    }

    // MARK: - Zutaten

    private var zutatenSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
            Text("Zutaten")
                .appText(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.s24)

            VStack(spacing: 0) {
                ForEach(viewModel.items) { item in
                    IngredientRow(item: item) { viewModel.toggleChecked(item) }
                    if item.id != viewModel.items.last?.id {
                        Divider()
                            .overlay(AppTheme.Colors.divider)
                            .padding(.leading, AppTheme.Spacing.s24 + 24 + AppTheme.Spacing.s12)
                    }
                }
            }
        }
    }
}

// MARK: - Recipe card (image + bottom scrim + name + delete)

private struct RecipeShoppingCard: View {
    let recipe: RecipeModel
    let onDelete: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private let width: CGFloat = 156
    private let height: CGFloat = 116

    var body: some View {
        artwork
            .frame(width: width, height: height)
            .overlay {
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.7)],
                               startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                Text(recipe.title)
                    .appText(.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(.horizontal, AppTheme.Spacing.s12)
                    .padding(.bottom, AppTheme.Spacing.s8)
            }
            .overlay(alignment: .topTrailing) { deleteButton }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .task(id: recipe.id) {
                image = await RecipeThumbnailStore.thumbnail(for: recipe.id,
                                                             pixelSize: width * displayScale)
            }
    }

    @ViewBuilder private var artwork: some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Rectangle()
                .fill(AppTheme.Colors.track)
                .overlay(Image(systemName: "fork.knife")
                    .foregroundStyle(AppTheme.Colors.textFaded))
        }
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(AppTheme.Spacing.s6)
                .background(.black.opacity(0.45), in: Circle())
        }
        .padding(AppTheme.Spacing.s6)
        .accessibilityLabel("\(recipe.title) aus der Einkaufsliste entfernen")
    }
}

// MARK: - Ingredient row (checkbox + name + quantity pill)

private struct IngredientRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: AppTheme.Spacing.s12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? AppTheme.Colors.accent : AppTheme.Colors.hairline)
                    .frame(width: 24, height: 24)

                Text(item.name)
                    .appText(.body)
                    .strikethrough(item.isChecked, color: AppTheme.Colors.textSecondary)
                    .foregroundStyle(item.isChecked ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)

                Spacer(minLength: AppTheme.Spacing.s12)

                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .appText(.label)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.vertical, AppTheme.Spacing.s4)
                        .padding(.horizontal, AppTheme.Spacing.s8)
                        .background(AppTheme.Colors.neutralTint, in: Capsule())
                }
            }
            .padding(.horizontal, AppTheme.Spacing.s24)
            .padding(.vertical, AppTheme.Spacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
