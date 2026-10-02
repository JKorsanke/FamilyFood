# Design system

The design system is the folder `FamilyFood/DesignSystem/`: one file of tokens, a handful of SwiftUI components composed from those tokens, and a gallery that shows all of it on one screen.

| File | Contents |
|---|---|
| `AppTheme.swift` | tokens: colours, spacing, corner radius, type roles |
| `AppFonts.swift` | registration of the bundled fonts |
| `Artwork.swift` | resolves illustration and brand-mark asset names |
| `FFButton.swift`, `FFCard.swift`, `FFListRow.swift`, `FFHeader.swift`, `FFSearchField.swift` | core components |
| `ThemeGallery.swift` | every token and component in one view |

For how the app is put together, see [ARCHITECTURE.md](ARCHITECTURE.md).

## The rule

**A value that is not in `AppTheme` is not in the app.** Views use no raw hex colour, no system font shortcut such as `.font(.headline)`, and no spacing or radius value that is off the scale. To change how something looks, change the token, not the call site. If the value you need does not exist, add a token (see below) and use it.

Where the rule holds today, and where it does not yet:

- Built from tokens: onboarding, the week view of the weekly plan, the shopping list, the tab headers and the recipe search field.
- Still styled with SwiftUI system fonts and colours: the recipe import screens, recipe detail and list rows, the body of the Kita import tab, the Settings form, and the sheets of the weekly plan. New and changed UI should follow the rule; moving one of these screens onto tokens is a welcome contribution.
- A few dimensions are literals rather than tokens: tap-target heights, icon-tile sizes, stroke widths and SF Symbol sizes (set as a font on the symbol image).

The palette is light-only. Colours are fixed sRGB values; there are no dark-appearance variants, so the app declares itself light-only (`UIUserInterfaceStyle` is `Light` in the app's `info:` block in `project.yml`). A dark palette would mean adding dark variants to every colour token first.

## Tokens

All tokens are static members of nested types in `AppTheme`.

### Colours: `AppTheme.Colors`

Names describe the role, never the hue.

| Token | Role |
|---|---|
| `surface` | screen and card background |
| `textPrimary`, `textSecondary` | main and supporting text |
| `textPlaceholder` | placeholder text |
| `textFaded` | disabled or decorative text only |
| `hairline` | borders of controls and cards |
| `divider` | list separators |
| `track` | inactive progress segments, muted fills |
| `accent` | the one brand colour: primary actions, selection, illustrations |
| `onAccent` | text and icons on an accent fill |
| `accentTint` | selected fill, icon tiles, badges |
| `neutralTint` | neutral badge and search-field fill |
| `onAccentTint` | icon tile on an accent fill |
| `onAccentSecondary` | secondary text on an accent fill |
| `destructive`, `success` | semantic states. Defined and shown in the gallery; no screen uses them yet |

Naming scheme: names that start with "text" are for text on `surface`, names that start with "on" are for content placed on the accent colour, names that end in "Tint" are low-opacity fills. Colours are created with `Color(hex:opacity:)`, an initializer defined in the same file and used nowhere else in the app.

### Spacing: `AppTheme.Spacing`

`s2`, `s4`, `s6`, `s8`, `s10`, `s12`, `s14`, `s16`, `s20`, `s24`, `s32`, `s40`. The name is the value in points. The scale is a 4-point grid plus four half-steps (2, 6, 10, 14). `s24` is the horizontal screen margin.

### Corner radius: `AppTheme.Radius`

| Token | Used for |
|---|---|
| `sm` | icon tiles |
| `md` | buttons, list and selection rows |
| `lg` | cards |
| `pill` | fully rounded shapes. Defined but currently unused: the components draw pills with `Capsule()` |

### Type: `AppTheme.TextRole`

A text role bundles font family, size, weight, line height, tracking, the Dynamic Type style it scales with, and whether the text is uppercased. Families are named in `AppTheme.FontFamily`: `display` (Inter Tight), `text` (Inter), `handwritten` (Gaegu).

| Role | Family | Typical use |
|---|---|---|
| `displayXL` | display | largest title; currently shown only in the gallery |
| `display` | display | screen titles |
| `headline` | display | section headings, day labels |
| `brand` | handwritten | the app wordmark |
| `cta` | text | button labels, row and card titles |
| `body` | text | paragraphs, subtitles, input text |
| `label` | text | meal names, pills, tertiary buttons |
| `caption` | text | hints, card subtitles |
| `footnote` | text | metadata lines |
| `overline` | text | uppercase badge text |
| `eyebrow` | text | uppercase, widely tracked line above a title |

Apply a role with `appText(_:)`. It sets font, tracking, line spacing and text case; colour is set separately:

```swift
Text(OnboardingCopy.Welcome.headline)
    .appText(.display)
    .foregroundStyle(AppTheme.Colors.textPrimary)
```

Every role is built with `Font.custom(_:size:relativeTo:)`, so all text scales with Dynamic Type.

## Core components

Each component file ends with a `#Preview`.

**`FFButton`**: the app's button. `kind` is `.primary` (accent fill), `.secondary` (accent tint) or `.tertiary` (text only); full width by default; the disabled state comes from SwiftUI's `.disabled(true)`. `FFButtonStyle` is the same look as a `ButtonStyle`.

```swift
FFButton(title: OnboardingCopy.weiter, kind: .primary) { vm.advance() }
FFButton(title: OnboardingCopy.ueberspringen, kind: .tertiary) { vm.skip() }
```

**`FFCard`**: a container with padding and the card radius. `FFCardKind` is `.standard` (surface with hairline border) or `.emphasized` (accent fill).

```swift
FFCard {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.s8) {
        // content
    }
}
```

**`FFActionCard`**: a tappable card composed on `FFCard`, with icon tile, title, subtitle and chevron.

```swift
FFActionCard(
    icon: OnboardingCopy.NextAction.kitaIcon,
    title: OnboardingCopy.NextAction.kitaTitle,
    subtitle: OnboardingCopy.NextAction.kitaSubtitle,
    action: onKita
)
```

**List rows** (`FFListRow.swift`): `FFSelectionRow` is a selectable row with icon, title and a check accessory; `FFFeatureRow` is a static row with icon tile and label.

```swift
FFSelectionRow(
    icon: style.systemImage,
    title: style.displayName,
    isSelected: vm.draft.dietStyle == style
) { vm.draft.dietStyle = style }

FFFeatureRow(icon: benefit.icon, title: benefit.label)
```

**Headers** (`FFHeader.swift`), five variants:

- `FFScreenHeader`: title of a tab's root screen with an optional trailing action. It replaces the system large title, so the screen hides its navigation bar.
- `FFHeaderIconButton`: the SF Symbol action for that trailing slot.
- `FFScreenTitle`: title with optional subtitle inside a screen.
- `FFProgressHeader`: onboarding chrome with back chevron and segmented progress.
- `FFBrandHeader`: app mark and wordmark.

```swift
FFScreenHeader(title: "Rezepte") {
    FFHeaderIconButton(systemImage: "plus",
                       accessibilityLabel: "Rezept hinzufügen",
                       tint: AppTheme.Colors.accent) { showingImport = true }
}

FFScreenTitle(title: page.title, subtitle: page.subtitle)

FFProgressHeader(step: min(vm.stepIndex, dataStepCount),
                 total: dataStepCount,
                 onBack: { vm.back() },
                 onSelect: { vm.jumpTo($0) })
```

**`FFSearchField`**: inline search field for screens whose `FFScreenHeader` replaced the navigation bar. Its `isStatic` flag draws the value as plain text and exists only for off-screen rendering of the gallery.

```swift
FFSearchField(text: $searchText, prompt: "Rezepte suchen")
```

### Onboarding-local components

`FamilyFood/Features/Onboarding/Views/OnboardingComponents.swift` holds components that only onboarding needs. They are composed from the same tokens.

- `FFOnboardingIllustration`: a hero illustration tinted with the accent colour.
- `FFTogglePill`: a multi-select pill, optionally with a leading check.
- `FFStepperRow`: a label with a minus/value/plus stepper.
- `FlowLayout`: a wrapping layout for pills.

```swift
FFOnboardingIllustration(name: "onb-00-welcome", maxHeight: 140)

FlowLayout(spacing: AppTheme.Spacing.s8) {
    ForEach(Weekday.allCases) { day in
        FFTogglePill(
            title: day.shortName,
            isSelected: vm.draft.warmMealDays.contains(day)
        ) { vm.toggleWarmDay(day) }
    }
}

FFStepperRow(label: OnboardingCopy.Household.adults,
             sublabel: OnboardingCopy.Household.adultsAge,
             value: $vm.draft.adults, range: 1...9)
```

## Adding or changing a token

1. Edit `FamilyFood/DesignSystem/AppTheme.swift`. Changing a value is a one-line change; every call site follows.
2. Name a new token after its role and keep to the scheme of its group: a colour as a `static let` in `AppTheme.Colors`; a spacing step named after its point value, like `s16`; a text role as a `static let` on `AppTheme.TextRole`, so that the leading-dot syntax of `appText(_:)` works. Give a text role a `relativeTo` style so it scales with Dynamic Type.
3. Show it in `ThemeGallery.swift`: a swatch for a colour, a specimen line for a text role. The hex labels under the swatches are hand-written strings, so update the label when you change a colour value.
4. `FamilyFoodTests/AppThemeTests.swift` pins a few values (two spacing steps, the three radii, the accent colour). If you change one of them on purpose, change the test in the same commit.
5. Look at the gallery preview, then run `scripts/test.sh`.

## ThemeGallery

`ThemeGallery` shows colour swatches, the type ramp and the core components in one scrolling view. It is not reachable from the running app. Open `FamilyFood/DesignSystem/ThemeGallery.swift` in Xcode and use the canvas preview named "ThemeGallery" to see a token change land across the whole system.

`ThemeGalleryRenderTests` renders `ThemeGalleryContent` (the non-scrolling body of the gallery) off-screen with `ImageRenderer` in the test suite. It is a smoke test: it fails when the gallery cannot be rendered, for example after a component change that breaks it. It does not compare pixels against a stored image.

## Fonts

Three font files are bundled in `FamilyFood/Resources/Fonts/`, each with its licence text next to it. All three are licensed under the SIL Open Font License 1.1.

| Font | File | Licence file | Used as |
|---|---|---|---|
| Inter | `Inter.ttf` | `Inter-OFL.txt` | `FontFamily.text` |
| Inter Tight | `InterTight.ttf` | `InterTight-OFL.txt` | `FontFamily.display` |
| Gaegu (bold) | `Gaegu-Bold.ttf` | `Gaegu-OFL.txt` | `FontFamily.handwritten` |

The fonts are registered twice, on purpose. They are listed under `UIAppFonts` in the app's Info.plist (defined in `project.yml`), which loads them at launch. `AppFonts.registerIfNeeded()` registers them in code as well, so they are available in previews and unit tests; it does nothing when a family is already registered. `FamilyFoodApp` calls it at start, and so does every `#Preview` in the design system.

To add a font: put the file and its licence into `FamilyFood/Resources/Fonts/`, add the file name to `UIAppFonts` in `project.yml`, add a line to `AppFonts.registerIfNeeded()`, add the family name to `AppTheme.FontFamily`, and run `xcodegen generate`.

## Artwork

Illustrations and marks live in `FamilyFood/Resources/Assets.xcassets`:

- `onb-00-welcome` to `onb-06-ready`: onboarding illustrations
- `ff-whisk-mark`: the brand mark
- `ic-generate-whisk`, `ic-generate-spoon`: the glyph of the "generate" button in the weekly plan (`MealPlanGenerateIcon` selects which one)
- `AppIcon`: the app icon

The illustrations, the mark and the glyphs are single-colour SVGs with template rendering, so they carry no colour of their own. The view tints them with a token: illustrations and the generate glyph with `AppTheme.Colors.accent`, the brand mark with `AppTheme.Colors.onAccent` on its accent tile.

The artwork in the repository is simple placeholder art. Always load it through `Artwork.name(_:)`:

```swift
Image(Artwork.name(name))
    .renderingMode(.template)
    .resizable()
    .scaledToFit()
    .frame(maxWidth: .infinity, maxHeight: maxHeight)
    .foregroundStyle(AppTheme.Colors.accent)
    .accessibilityHidden(true)
```

`Artwork.name(_:)` returns the name of a local original when a build bundles one, otherwise the placeholder's name. The mechanism is described in [ARCHITECTURE.md](ARCHITECTURE.md), "Seed data and the local overlay".

To add an illustration: add an image set with the base name to the catalog (SVG, "Render As: Template Image"), reference it through `Artwork.name(_:)`, and add the name to the list in `FamilyFoodTests/ArtworkTests.swift`. That test makes sure every name the app uses has art in the repository's own catalog.

## UI language

All user-facing strings are German and written directly in the code. There is no localisation layer yet: no String Catalog and no localisation lookups. Onboarding text is collected in `OnboardingCopy`; other strings sit in their views and in display helpers such as `Weekday.displayName` and `DietStyle.displayName`.

Some German strings are also data, not only labels: the raw values of `MainIngredient`, the allergen names in `allAllergens`, and the names the LLM prompts ask for. They are stored with recipes and compared by the suggestion engine, so a future localisation has to separate these identifiers from their labels.

Comments and most identifiers are in English; a few identifiers name German domain terms, for example the cases of `MainIngredient`. Write new user-facing text in German.
