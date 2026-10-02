import SwiftUI

/// The design system on one screen: every token + all four components
/// in one view — open the preview to see a token change land across the whole system.
struct ThemeGallery: View {
    var body: some View {
        ScrollView {
            ThemeGalleryContent()
        }
        .background(AppTheme.Colors.surface)
        .onAppear { AppFonts.registerIfNeeded() }
    }
}

/// Non-scrolling body — also the off-screen render target for snapshots (ImageRenderer can't
/// render a ScrollView/Lazy container).
struct ThemeGalleryContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s32) {
            header
            colorSection
            typeSection
            buttonSection
            cardSection
            rowSection
            headerSection
            searchSection
        }
        .padding(AppTheme.Spacing.s24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s4) {
            Text("DESIGN SYSTEM").appText(.eyebrow).foregroundStyle(AppTheme.Colors.textSecondary)
            Text("FamilyFood · Clean").appText(.display).foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }

    // MARK: Colors
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
            sectionTitle("Farben")
            FlowGrid(items: Self.swatches) { swatch in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.s4) {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                        .fill(swatch.color)
                        .frame(width: 96, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                                .stroke(AppTheme.Colors.hairline, lineWidth: 1)
                        )
                    Text(swatch.name).appText(.footnote).foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(swatch.hex).appText(.footnote).foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: Type
    private var typeSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
            sectionTitle("Typografie")
            specimen("displayXL", .displayXL)
            specimen("display", .display)
            specimen("headline", .headline)
            specimen("cta", .cta)
            specimen("body", .body)
            specimen("label", .label)
            specimen("caption", .caption)
            specimen("footnote", .footnote)
            HStack(spacing: AppTheme.Spacing.s12) {
                Text("OVERLINE").appText(.overline).foregroundStyle(AppTheme.Colors.textSecondary)
                Text("EYEBROW").appText(.eyebrow).foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private func specimen(_ name: String, _ role: AppTheme.TextRole) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.s12) {
            Text(name).appText(.footnote).foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(width: 72, alignment: .leading)
            Text("Familienessen").appText(role).foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }

    // MARK: Components
    private var buttonSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
            sectionTitle("Button")
            FFButton(title: "Weiter", kind: .primary)
            FFButton(title: "Kita-Plan wählen", kind: .secondary)
            FFButton(title: "Überspringen", kind: .tertiary)
            FFButton(title: "Deaktiviert", kind: .primary).disabled(true)
        }
    }

    private var cardSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
            sectionTitle("Card")
            FFActionCard(icon: "camera.fill",
                         title: "Kita-Plan hochladen",
                         subtitle: "Fotografiere den Speiseplan – wir übernehmen ihn automatisch.",
                         kind: .emphasized)
            FFActionCard(icon: "fork.knife",
                         title: "Rezept hinzufügen",
                         subtitle: "Füge ein Lieblingsrezept hinzu.")
        }
    }

    private var rowSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
            sectionTitle("List row")
            FFSelectionRow(icon: "fork.knife", title: "Mit Fleisch", isSelected: true)
            FFSelectionRow(icon: "leaf", title: "Vegetarisch")
            FFFeatureRow(icon: "calendar", title: "Wochenplan ohne Kopfzerbrechen")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s16) {
            sectionTitle("Header")
            FFProgressHeader(step: 3, total: 5, onBack: {})
            FFBrandHeader()
            FFScreenTitle(title: "Wie ernährt ihr euch?",
                          subtitle: "Wir schlagen passende Gerichte vor.")
            FFScreenHeader(title: "Rezepte") {
                FFHeaderIconButton(systemImage: "plus", accessibilityLabel: "Rezept hinzufügen",
                                   tint: AppTheme.Colors.accent) {}
            }
            .padding(.horizontal, -AppTheme.Spacing.s24)   // brings its own screen margin
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
            sectionTitle("Search field")
            FFSearchField(text: .constant(""), prompt: "Rezepte suchen", isStatic: true)
            FFSearchField(text: .constant("Pancakes"), prompt: "Rezepte suchen", isStatic: true)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).appText(.eyebrow).foregroundStyle(AppTheme.Colors.accent)
    }

    // MARK: Swatch data
    private struct Swatch: Identifiable {
        let id = UUID(); let name: String; let hex: String; let color: Color
    }
    private static let swatches: [Swatch] = [
        .init(name: "surface", hex: "#FFFFFF", color: AppTheme.Colors.surface),
        .init(name: "textPrimary", hex: "#0E1116", color: AppTheme.Colors.textPrimary),
        .init(name: "textSecondary", hex: "#5C636B", color: AppTheme.Colors.textSecondary),
        .init(name: "textPlaceholder", hex: "#6E757D", color: AppTheme.Colors.textPlaceholder),
        .init(name: "textFaded", hex: "#C9CED4", color: AppTheme.Colors.textFaded),
        .init(name: "hairline", hex: "#C9CED4", color: AppTheme.Colors.hairline),
        .init(name: "track", hex: "#E6E8EB", color: AppTheme.Colors.track),
        .init(name: "accent", hex: "#0040E0", color: AppTheme.Colors.accent),
        .init(name: "accentTint", hex: "8%", color: AppTheme.Colors.accentTint),
        .init(name: "neutralTint", hex: "5%", color: AppTheme.Colors.neutralTint),
        .init(name: "destructive", hex: "#C81E1E", color: AppTheme.Colors.destructive),
        .init(name: "success", hex: "#15803D", color: AppTheme.Colors.success),
    ]

    /// Non-lazy wrap grid (renders fully under ImageRenderer, unlike LazyVGrid).
    private struct FlowGrid<Item: Identifiable, Cell: View>: View {
        let items: [Item]
        var columns: Int = 3
        @ViewBuilder let cell: (Item) -> Cell

        var body: some View {
            let rows = stride(from: 0, to: items.count, by: columns).map {
                Array(items[$0 ..< min($0 + columns, items.count)])
            }
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: AppTheme.Spacing.s12) {
                        ForEach(row) { cell($0) }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

#Preview("ThemeGallery") {
    let _ = AppFonts.registerIfNeeded()
    ThemeGallery()
}
