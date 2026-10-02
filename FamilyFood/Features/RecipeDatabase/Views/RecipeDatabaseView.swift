import SwiftUI
import SwiftData

enum RecipeSortOption: String, CaseIterable, Identifiable {
    case newestFirst  = "Neueste zuerst"
    case oldestFirst  = "Älteste zuerst"
    case titleAZ      = "A – Z"
    case titleZA      = "Z – A"

    var id: String { rawValue }

    var descriptor: SortDescriptor<RecipeModel> {
        switch self {
        case .newestFirst: return SortDescriptor(\RecipeModel.dateAdded, order: .reverse)
        case .oldestFirst: return SortDescriptor(\RecipeModel.dateAdded, order: .forward)
        case .titleAZ:     return SortDescriptor(\RecipeModel.title,     order: .forward)
        case .titleZA:     return SortDescriptor(\RecipeModel.title,     order: .reverse)
        }
    }
}

struct RecipeDatabaseView: View {
    @State private var showFavouritesOnly = false
    @State private var sortOption: RecipeSortOption = .newestFirst
    @State private var searchText = ""
    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FFScreenHeader(title: "Rezepte") {
                    FFHeaderIconButton(systemImage: "plus",
                                       accessibilityLabel: "Rezept hinzufügen",
                                       tint: AppTheme.Colors.accent) { showingImport = true }
                }
                FFSearchField(text: $searchText, prompt: "Rezepte suchen")
                    .padding(.horizontal, AppTheme.Spacing.s24)
                filterBar
                    .padding(.horizontal, AppTheme.Spacing.s24)
                    .padding(.top, AppTheme.Spacing.s12)
                    .padding(.bottom, AppTheme.Spacing.s8)
                Divider()
                RecipeListContent(
                    showFavouritesOnly: showFavouritesOnly,
                    sortOption: sortOption,
                    searchText: searchText
                )
            }
            .toolbar(.hidden, for: .navigationBar)   // FFScreenHeader replaces the large title
            .sheet(isPresented: $showingImport) {
                RecipeImportView(isPresented: $showingImport)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Favourites toggle
            Button {
                showFavouritesOnly.toggle()
            } label: {
                Label(showFavouritesOnly ? "Alle" : "Favoriten",
                      systemImage: showFavouritesOnly ? "heart.fill" : "heart")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showFavouritesOnly ? Color.red.opacity(0.12) : Color.secondary.opacity(0.1))
                    .foregroundStyle(showFavouritesOnly ? .red : .secondary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Sort picker
            Menu {
                ForEach(RecipeSortOption.allCases) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Label(sortOption.rawValue, systemImage: "arrow.up.arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: — Child view owns the @Query (enables dynamic sort + filter)

private struct RecipeListContent: View {
    @Query private var allRecipes: [RecipeModel]
    let searchText: String

    init(showFavouritesOnly: Bool, sortOption: RecipeSortOption, searchText: String) {
        self.searchText = searchText
        let sort = [sortOption.descriptor]
        if showFavouritesOnly {
            _allRecipes = Query(filter: #Predicate { $0.isFavourite }, sort: sort)
        } else {
            _allRecipes = Query(sort: sort)
        }
    }

    private var recipes: [RecipeModel] {
        guard !searchText.isEmpty else { return allRecipes }
        return allRecipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        if recipes.isEmpty {
            ContentUnavailableView(
                "Keine Rezepte",
                systemImage: "fork.knife",
                description: Text(searchText.isEmpty ? "Füge dein erstes Rezept hinzu." : "Keine Treffer für \"\(searchText)\".")
            )
        } else {
            List {
                ForEach(recipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                        RecipeRowView(recipe: recipe)
                    }
                    // Rows on the 24pt screen axle; the system default inset is 16–20pt.
                    .listRowInsets(EdgeInsets(top: AppTheme.Spacing.s16, leading: AppTheme.Spacing.s24,
                                              bottom: AppTheme.Spacing.s16, trailing: AppTheme.Spacing.s24))
                    .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }   // separator ends on the axle too
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)   // the inline search field has no Cancel button
        }
    }
}

// MARK: — Row

struct RecipeRowView: View {
    let recipe: RecipeModel

    var body: some View {
        HStack(spacing: 12) {
            RecipeImageView(recipeId: recipe.id, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let mins = recipe.displayTotalTime {
                        Label("\(mins) Min.", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: recipe.dietStyle.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(recipe.dietStyle.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if recipe.isFamilyFriendly {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            if recipe.isFavourite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: — Shared image view

/// Displays a recipe's locally stored image, decoded at display size. `AsyncImage`
/// is the wrong tool for local files — it decodes the full-resolution JPEG for a
/// 56-pt cell and re-checks the file system on every body evaluation.
struct RecipeImageView: View {
    let recipeId: UUID
    /// Square edge in points for thumbnails; `nil` fills the proposed width (hero).
    var size: CGFloat? = nil

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: recipeId) {
            image = await RecipeThumbnailStore.thumbnail(
                for: recipeId,
                pixelSize: (size ?? 440) * displayScale
            )
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.12))
            .overlay(Image(systemName: "fork.knife").font(.caption).foregroundStyle(.tertiary))
    }
}

/// Decodes recipe images off the main actor at a bounded pixel size and caches the
/// results, so list scrolling never pays a full-resolution JPEG decode twice.
enum RecipeThumbnailStore {
    private static let cache = NSCache<NSString, UIImage>()

    static func thumbnail(for recipeId: UUID, pixelSize: CGFloat) async -> UIImage? {
        let key = "\(recipeId.uuidString)-\(Int(pixelSize))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let url = ImageStorageService.shared.imageURL(for: recipeId),
              let full = UIImage(contentsOfFile: url.path),
              let thumb = await full.byPreparingThumbnail(
                  ofSize: CGSize(width: pixelSize, height: pixelSize))
        else { return nil }

        cache.setObject(thumb, forKey: key)
        return thumb
    }
}
