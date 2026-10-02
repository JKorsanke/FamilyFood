# Architecture

FamilyFood is a native iOS app (Swift, SwiftUI, iOS 17+) that plans a family's warm meals for the week around what the children already eat at kindergarten ("Kita"), and turns the plan into a shopping list. It has no backend: all data stays on the device.

This document is a map of the code, not a file listing. For setup and conventions see [CONTRIBUTING.md](../CONTRIBUTING.md); for tokens and UI components see [DESIGN-SYSTEM.md](DESIGN-SYSTEM.md).

## Repository layout

```
FamilyFood/                 app target
├── App/                    entry point, onboarding gate, tab bar, shared app state
├── Features/<Feature>/     one folder per screen area
│   ├── Views/              SwiftUI views
│   └── ViewModels/         one ObservableObject per screen that has logic
├── Models/                 SwiftData models and plain Codable value types
├── Services/               business logic, stores, parsers, the only network code
├── Utilities/              small helpers (week calendar, logging, text cleanup, allergens)
├── DesignSystem/           tokens and core components
└── Resources/              asset catalog, fonts, sample recipes
ShareExtension/             share-sheet target
FamilyFoodTests/            unit tests (XCTest)
Config/                     xcconfig files: signing, bundle ids, App Group
scripts/                    test runner and pre-commit hook
project.yml                 XcodeGen project definition
```

Features under `FamilyFood/Features/`:

| Folder | What it is |
|---|---|
| `MealPlan` | Weekly plan tab: week pager, day rows, meal sheets, the "generate" action |
| `RecipeDatabase` | Recipe list (search, sort, favourites) and recipe detail |
| `RecipeImport` | Add a recipe by URL, photo or manual entry; `ImportInbox/` handles shared items |
| `KindergartenImport` | Import a Kita meal plan from camera, photo library or PDF |
| `ShoppingList` | Shopping list derived from the current week's plan |
| `Settings` | Household settings and the API key field |
| `Onboarding` | First-run flow that fills in the initial settings |

## App structure

`FamilyFoodApp` is the entry point. On launch it registers the bundled fonts, creates the SwiftData `ModelContainer`, then runs the first-launch seed and two one-time data migrations, and finally asks `ImportInboxCoordinator` to look for shared items.

`RootView` shows `OnboardingFlowView` until the `hasCompletedOnboarding` flag is set, then `ContentView`, a `TabView` with five tabs (`AppTab`): weekly plan, recipes, shopping list, Kita import, settings.

MVVM as practised here:

- A view owns its view model with `@StateObject`. View models are `@MainActor` `ObservableObject` classes (`MealPlanViewModel`, `ShoppingListViewModel`, `KindergartenImportViewModel`, `RecipeImportViewModel`, `ImportInboxViewModel`, `OnboardingViewModel`).
- Features without logic of their own have no view model: `RecipeDatabase` reads SwiftData with `@Query`, `Settings` binds to `@AppStorage`.
- Logic lives in `Services/` and `Models/`. Most services are structs with their dependencies as initializer parameters that default to production (`PlanStore()`, `KitaPlanImportService()`), so tests can pass a temporary directory or a fake.
- App-wide state is injected through the environment: `AppStore` (the imported Kita plans; unrelated to Apple's App Store), `ImportInboxCoordinator`, and the SwiftData model container.

## Persistence

Three mechanisms, each for one kind of data.

| Data | Mechanism | Location on device | Code |
|---|---|---|---|
| Recipes with ingredient groups and ingredients | SwiftData | the app's default model container | `RecipeModel`, `IngredientGroupModel`, `RecipeIngredientModel`; written through `RecipeDatabaseService` |
| Recipe images | JPEG files | `<Documents>/RecipeImages/<recipe id>.jpg` | `ImageStorageService` |
| Weekly plans | JSON file | `<Application Support>/MealPlans/weekly_plans.json` | `PlanStore`, owned by `MealPlanViewModel` |
| Kita plans | JSON file | `<Application Support>/MealPlans/kita_plans.json` | `PlanStore`, owned by `AppStore` |
| Shopping-list overrides | JSON file | `<Application Support>/ShoppingList/shopping_list.json` | `ShoppingListStore`, owned by `ShoppingListViewModel` |
| Household settings | `UserDefaults` via `@AppStorage("userSettings")` | one JSON string | `UserSettings` |
| API key | `UserDefaults` | key `anthropicApiKey` | `AnthropicKeyStore` |
| Flags | `UserDefaults` | `hasCompletedOnboarding`, `hasSeededRecipes`, `hasCleanedRecipeTextsV1`, `hasAppliedAllergenTagsV1` | `RootView`, `FamilyFoodApp` |
| Shared items waiting for import | files | `Inbox/` in the App Group container | `SharedImportInbox` |

Things worth knowing:

- **Plans are value types.** `WeeklyPlan`, `DaySlot`, `PlannedMeal` and `KitaMealPlan` are plain `Codable` structs. The owning object writes the whole array on every change (`didSet`). A plan refers to a recipe only by id (`MealKind.recipe(id:engineId:)`) plus a name snapshot; views resolve the id against SwiftData.
- **Weeks are identified by `WeekKey`**, an ISO week such as `2026-W25`, not by a date. All week arithmetic goes through `Calendar.mondayFirst`.
- **`PlanStore` loads tolerantly.** One undecodable record is dropped instead of discarding the file, and the original file is first copied to `<name>.backup.json`.
- **The shopping list is derived, not stored.** `ShoppingListViewModel` reads the current week's plan, resolves its recipes and merges their ingredients with `ShoppingListBuilder.aggregate(_:)`. Only the user's overrides are saved (`ShoppingListState`: removed recipes, ticked items).
- **`UserSettings` is stored as one JSON string.** It is `RawRepresentable`; `@AppStorage` encodes it through a private `Storage` struct (see "a new setting" below).
- **The API key is in `UserDefaults`, not in the Keychain.**

## The suggestion engine

`SuggestionEngine.generateWeeklyPlan(recipes:kitaPlans:settings:week:)` builds one week. It is called from `MealPlanViewModel.generatePlan`, which replaces the displayed week's plan with the result. The engine starts from an empty week, so meals set by hand in that week are replaced too.

```
recipes, Kita plans, settings, week
        │
        ▼
1 layout      which days get a warm meal
2 blocking    main ingredients the Kita serves this week
3 scoring     drop excluded recipes, score the rest
4 assignment  best recipe per open day, three fallback passes
5 save        persist the "last recommended" stamps
        │
        ▼
   WeeklyPlan
```

**1. Warm-meal-day layout.** A new `WeeklyPlan` has seven `DaySlot`s, Monday to Sunday. `applyWarmMealLayout(_:)` gives every day that is not in `UserSettings.warmMealDays` an automatic "Abendbrot" (a cold evening meal, `MealKind.abendbrot(auto: true)`). The remaining days stay empty and are the slots the engine fills.

**2. Kita-plan blocking.** For every Kita plan that belongs to the week (`KitaWeekMatcher.matches`), the Monday-to-Friday `mainIngredient` values are collected, lowercased. The category `Sonstiges` ("other") is ignored. This set is the starting value of "ingredients already used this week".

**3. Hard exclusions and scoring.** Each recipe is scored once. A recipe is excluded when:

- any of its `allergenTags` is in `UserSettings.allergens`;
- the household is not omnivore and the recipe's `dietStyle` is neither the household's nor `vegan` (so a recipe with diet style `unknown` is only suggested to omnivore households);
- `UserSettings.maxCookTimeMinutes` is set and the recipe's `displayTotalTime` is known and larger. A recipe with unknown time passes.

The others get a score:

```
score = recency + favourite - swapPenalty + noise

recency      1.0 if never recommended, else min(days since lastRecommendedDate / 60, 1.0)
favourite    0.3 if isFavourite, else 0
swapPenalty  min(swapCount * 0.1, 0.5)
noise        random value in 0...0.05
```

`swapCount` grows when the user replaces a recipe the engine placed with a different one (`MealPlanViewModel.assignRecipe`).

**4. Assignment with three fallback passes.** Open slots are filled in weekday order. For each slot:

1. Pass 1 takes the highest-scoring recipe that is not yet in this week's plan and whose main ingredient has not been used (by the Kita or by an earlier day). A recipe without a main ingredient is never blocked.
2. Pass 2 drops the ingredient rule: a repeated or Kita-conflicting main ingredient is accepted, a repeated recipe is not.
3. Pass 3 takes the highest-scoring recipe overall, repeats allowed.

Hard exclusions are never relaxed. If no recipe survives them, the slot stays empty. After each assignment the recipe's main ingredient joins the used set and the recipe is stamped with `lastRecommendedDate`.

**5. Save.** The stamps are persisted with a single `save()` per generation. Because stamping happens at generation time, generating again produces a different plan: the recipes just suggested now have a recency near zero.

For tests, the clock and the noise source are initializer parameters, and the engine sees SwiftData only through the one-method protocol `ModelSaving`. `FamilyFoodTests/SuggestionEngineTests.swift` pins each rule above.

## The import pipeline

Everything that enters the app from outside ends as either a `KitaMealPlan` or a `RecipeDraft`. Turning free text into one of the two is done by an LLM (Anthropic's Messages API, see "The network boundary"); everything before that step runs on the device.

### Share extension and inbox

```
Share sheet: a PDF or a web URL
      │  ShareViewController -> ShareImportReceiver
      ▼
App Group container, Inbox/      <id>.pdf or <id>.url, plus <id>.json (InboxDescriptor)
      │  app launch or return to foreground -> ImportInboxCoordinator.drain()
      ▼
ImportInboxHostView presents a sheet; ImportRoute.initial(for:) decides
      ├─ URL -> recipe import by URL (below)
      └─ PDF -> the user chooses
            ├─ "Speiseplan" -> Kita plan import (below) -> pick a child -> AppStore.kitaPlans
            └─ "Rezept"     -> first page rendered to an image -> recipe import by photo (below)
```

- The extension does no parsing and no networking. It only copies the payload into the shared container. It compiles `SharedImportInbox.swift`, `ShareImportReceiver.swift` and `Log.swift` from the app's sources (listed under its `sources:` in `project.yml`).
- An item stays in the inbox until `ImportInboxCoordinator.finish(_:)` removes it. `skip(_:)` only hides it for the session, so an abandoned import is offered again on the next launch.
- `ImportInboxHostView` is attached to `ContentView`, so shared items are presented once onboarding is complete.

### Kita plan import

Sources: camera, photo library or a PDF from the Kita import tab (`KindergartenImportView`), or a shared PDF. All of them go through `KitaPlanImportService`:

```
PDF ── PDFImportRenderer.extractText() ── 50 characters or more ───────┐
   └── less: firstPageImage() ── OCRService.extractText(from:) ────────┤
photo ────────────────────────── OCRService.extractText(from:) ────────┤
                                                                       ▼
                               AnthropicParsing.parseMealPlan(from:) -> KitaMealPlan
```

OCR is Apple's Vision framework on the device. The LLM receives the extracted text and returns, per weekday, a date, the meal name and a main-ingredient category from the `MainIngredient` vocabulary. The plan is appended to `AppStore.kitaPlans`, optionally assigned to a child. `KitaWeekMatcher` later decides which week a plan belongs to, from its loosely formatted date strings.

### Recipe import

`RecipeImportView` offers three sources. All produce a `RecipeDraft`.

| Source | Path | Review screen |
|---|---|---|
| URL, typed or shared | `WebScrapeParser.parse(url:)` fetches the page and looks for a schema.org `Recipe` in its JSON-LD (`parseJSONLD(from:sourceURL:)`) | no: a JSON-LD result is saved directly |
| URL without usable JSON-LD | the HTML is stripped to text (first 6000 characters) and sent to `AnthropicParsing.parseRecipe(from:sourceURL:source:)` | yes |
| Photo of a recipe, or page one of a shared PDF | `OCRRecipeParser`: on-device OCR, then the same LLM call | yes |
| Manual entry | `ManualEntryView` builds the draft from its form | the form itself |

`RecipeReviewView` lets the user correct the title, the classification (diet style, main ingredient) and the times; the recognised ingredients are shown read-only. `RecipeDatabaseService.save(_:)` then creates the `RecipeModel` with its groups and ingredients, infers allergen tags by keyword when the draft has none (`inferAllergenTags(from:)`), stores the image and saves. URL imports are de-duplicated by source URL (`recipeExists(withURL:)`). Text from web pages and from the LLM is cleaned of HTML remnants (`cleaningTexts()`).

The LLM sits behind one protocol, `AnthropicParsing`, with one implementation, `AnthropicService`. Parsers take `any AnthropicParsing`, so tests inject a fake and never touch the network. Without a stored key the call fails with `AnthropicError.missingKey` before any request to the API is made.

## Seed data and the local overlay

The repository ships an original sample set, `FamilyFood/Resources/recipes.json`: a JSON array of `BundledRecipe` records without source URLs or photos. On first launch `RecipeDatabaseService.seedFromBundle(_:)` inserts it into SwiftData, once, guarded by the `hasSeededRecipes` flag. A minimal record:

```json
{"id": 1, "title": "Tomatennudeln", "diet_style": "vegan", "main_ingredient": "Pasta",
 "total_time": "20",
 "ingredient_groups": [{"name": "", "ingredients": [
   {"amount": "300", "unit": "g", "name": "Spaghetti", "notes": ""}]}]}
```

A build can replace this content without changing the repository. `LocalOverlay/` is an optional source folder of the app target (`optional: true` in `project.yml`) and is gitignored. It exists so that a fork, or the maintainer, can bundle content they have the right to use but not to redistribute, without committing it.

```
LocalOverlay/
├── recipes.local.json     seed file in the same format; replaces the sample set
├── RecipeImages/          image files named by the records' "image" field
└── Artwork.xcassets/      asset catalog with original artwork in a "local" namespace
```

How the overlay is picked up:

- **Recipes.** `RecipeSeed.resourceNames` is `["recipes.local", "recipes"]`, in order of preference. If the bundle contains `recipes.local.json`, it is used instead of `recipes.json`.
- **Recipe images.** For a record with an `image` field, the seeder looks for that file name in the bundle root, then in a `RecipeImages` subdirectory, and copies it to the app's image directory.
- **Artwork.** `Artwork.name(_:)` returns `local/<name>` when the asset catalog has an image under that name, otherwise `<name>`. Views always load artwork through it, so an original replaces the placeholder with no code change. The `local` folder in the overlay catalog must have "Provides Namespace" enabled.
- **App icon.** The icon set name is the build setting `FF_APP_ICON_NAME` (default `AppIcon`, the placeholder). An overlay catalog can carry an icon set under another name and select it in `Config/Signing.local.xcconfig`.

Run `xcodegen generate` after adding or removing the folder. Seeding happens once per install, so switching seed files needs a fresh install. `FamilyFoodTests/RecipeSeedTests.swift` and `FamilyFoodTests/ArtworkTests.swift` check that the repository works without an overlay: the sample set is well-formed and fills a varied week for every diet style, and every artwork name has a placeholder.

## The network boundary

The app makes network requests in exactly three places. Each one is the direct result of an import the user started.

| Code | Destination | When | What is sent |
|---|---|---|---|
| `AnthropicService` (its private `complete` function) | `POST https://api.anthropic.com/v1/messages` | Kita plan import; recipe import by photo or PDF; recipe import by URL only when the page has no usable JSON-LD | the user's API key as a request header, and a prompt containing the OCR text or the stripped page text |
| `WebScrapeParser` (its private `fetchHTML` function) | the URL the user typed or shared | recipe import by URL | a plain GET request with the user agent `FamilyFood/1.0` |
| `ImageStorageService.downloadAndSave(from:forRecipeId:)` | the image URL named in that page's JSON-LD | when that recipe is saved | a plain GET request |

- **The API key is the user's own.** It is entered in the Settings tab (`UserSettingsView`), stored in `UserDefaults` and read through `AnthropicKeyStore`. No key is bundled. Without one, the LLM-backed imports fail with a message that points to Settings; planning, the recipe list, the shopping list, manual entry and URL import of pages with JSON-LD all work.
- **Images and PDFs are not uploaded.** Text is extracted on the device first (Vision OCR, PDFKit); only that text goes into the prompt.
- **The share extension makes no requests.**
- The recipe detail screen has a link that hands the recipe's source URL to the system browser. That is not a request made by the app.

Everything else runs on the device: the suggestion engine, the shopping list, OCR, PDF text extraction, allergen detection. There is no analytics or crash-reporting SDK, no account, no sync and no backend, and the project has no third-party packages.

If you add a network call, add it to the table above.

## Build configuration

**XcodeGen.** `project.yml` defines the project. `FamilyFood.xcodeproj` is generated from it with `xcodegen generate` and is not committed. `scripts/test.sh` regenerates the project and runs the tests.

| Target | Type | Sources |
|---|---|---|
| `FamilyFood` | application | `FamilyFood/`, plus `LocalOverlay/` when present |
| `FamilyFoodShareExtension` | app extension | `ShareExtension/` and three files shared with the app |
| `FamilyFoodTests` | unit-test bundle, depends on the app | `FamilyFoodTests/` |

`FamilyFood/Info.plist` and `ShareExtension/Info.plist` are written by XcodeGen from the `info:` blocks in `project.yml`. Change the block, not the file.

**Signing.** `Config/Signing.xcconfig` is applied to every configuration and defines four settings:

| Setting | Default | Used for |
|---|---|---|
| `FF_DEVELOPMENT_TEAM` | empty | `DEVELOPMENT_TEAM` of the app and the extension |
| `FF_BUNDLE_ID_PREFIX` | `org.example` | bundle ids `<prefix>.familyfood`, `<prefix>.familyfood.ShareExtension`, `<prefix>.familyfood.tests` |
| `FF_APP_GROUP` | derived: `group.<prefix>.familyfood` | both entitlements files and the Info.plists |
| `FF_APP_ICON_NAME` | `AppIcon` | name of the app icon set |

The defaults build, run and test in the simulator. The file ends by including `Config/Signing.local.xcconfig` if it exists. That file is gitignored; `Config/Signing.local.example.xcconfig` is the template for a device build with your own team and prefix.

**App Group.** The app and the share extension exchange files through an App Group container. `FamilyFood/FamilyFood.entitlements` and `ShareExtension/ShareExtension.entitlements` both name `$(FF_APP_GROUP)`. The same value reaches the code through the Info.plist key `FFAppGroupID`, which `SharedImportInbox.appGroupID(in:)` reads. If the key is missing or the container is unavailable, `SharedImportInbox()` returns `nil` and the inbox does nothing; the rest of the app is unaffected.

**Commit guard.** `scripts/hooks/pre-commit` rejects staged build artifacts and Anthropic API keys. Enable it once per clone with `git config core.hooksPath scripts/hooks`.

## Tests

`FamilyFoodTests/` has one XCTest file per unit. There is no UI-test target. The seams the tests rely on are the ones described above: stores and the inbox take a directory, LLM-backed code takes `any AnthropicParsing`, the share receiver takes a `SharedItemProviding`, the engine takes `ModelSaving`, a clock and a noise source. Tests need neither network nor API key.

## Where do I add…

### …a new recipe-import source

1. Write a parser in `FamilyFood/Services/` that returns a `RecipeDraft`, next to `WebScrapeParser` and `OCRRecipeParser`. If it needs the LLM, take `any AnthropicParsing` in the initializer.
2. If the origin should be recorded, add a case to `RecipeSource` in `FamilyFood/Models/RecipeModel.swift` and set `draft.source`.
3. Add a method to `RecipeImportViewModel`, a view under `FamilyFood/Features/RecipeImport/Views/`, and a row in `RecipeImportView`.
4. Send the draft to `RecipeReviewView`; it saves through `RecipeDatabaseService.save(_:)`.
5. To accept the source from the share sheet as well: add a case to `InboxKind`, handle it in `ShareImportReceiver.receive(_:)` and `ImportRoute.initial(for:)`, present it in `ImportInboxHostView.swift`, and extend the activation rule of the extension in `project.yml`.
6. If the source makes a network request, add it to "The network boundary".

### …a new main-ingredient category

Add a case to `MainIngredient` in `FamilyFood/Models/MainIngredient.swift`. Everything else follows from the enum: the LLM prompts are built from `MainIngredient.promptVocabulary`, and the pickers in `RecipeReviewView` and `ManualEntryView` iterate `MainIngredient.allCases`.

- The raw value is the stored value (`RecipeModel.mainIngredient` and `KitaMealPlan.Day.mainIngredient` are strings) and the user-visible label. Adding a case is safe. Renaming a raw value orphans stored data.
- `sonstiges` has a special meaning in the engine (it never blocks); keep it.
- Tag suitable records in `FamilyFood/Resources/recipes.json` with the new value. `RecipeSeedTests` checks that every sample record uses a value from the vocabulary.

### …a new setting

1. Add the property with a default value to `UserSettings` in `FamilyFood/Models/UserSettings.swift`.
2. Add it to the private `Storage` struct as an **optional**, and map it in `init?(rawValue:)` (with the default as fallback) and in `rawValue`. If the field were required, settings stored by an earlier version would fail to decode and `@AppStorage` would fall back to the defaults, resetting the user's household.
3. Add the control to `UserSettingsView`. If onboarding should ask for it, add it to the draft handled by `OnboardingViewModel`.
4. Read it where it matters, for example in `SuggestionEngine`.
5. Add a round-trip test and an "old JSON still decodes" test to `FamilyFoodTests/UserSettingsTests.swift`.

A stand-alone flag that is not part of the household settings can be a separate `@AppStorage` key, as `hasCompletedOnboarding` is.
