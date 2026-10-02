# Third-party notices and what the licence covers

FamilyFood's source code is released under the MIT Licence (see [LICENSE](LICENSE)). This
file lists the material in the repository that comes from others, and what is not covered by
the MIT grant.

## Fonts — SIL Open Font License 1.1

The app bundles three typefaces. Each is licensed under the SIL Open Font License, Version 1.1;
the full licence text ships next to each font file.

| Font | Copyright | Files | Licence text |
|---|---|---|---|
| Inter | Copyright 2020 The Inter Project Authors (https://github.com/rsms/inter) | `FamilyFood/Resources/Fonts/Inter.ttf` | `FamilyFood/Resources/Fonts/Inter-OFL.txt` |
| Inter Tight | Copyright 2022 The Inter Project Authors (https://github.com/rsms/inter-tight) | `FamilyFood/Resources/Fonts/InterTight.ttf` | `FamilyFood/Resources/Fonts/InterTight-OFL.txt` |
| Gaegu | Copyright 2018 The Gaegu Project Authors | `FamilyFood/Resources/Fonts/Gaegu-Bold.ttf` | `FamilyFood/Resources/Fonts/Gaegu-OFL.txt` |

The fonts remain under the OFL; the MIT Licence does not apply to them.

## Artwork in this repository

The illustrations, glyphs and the app icon in `FamilyFood/Resources/Assets.xcassets` are simple
placeholders drawn for this repository. They are covered by the MIT Licence like the code.

## Sample recipes

`FamilyFood/Resources/recipes.json` is a set of sample recipes written for this repository. It
is covered by the MIT Licence like the code.

## Not covered by the licence

- **The name "FamilyFood".** The MIT Licence grants rights in the code, not in the project's
  name.
- **The maintainer's original app icon, logo and illustrations.** They are not included in
  this repository. Builds published by the maintainer may use them; that does not license them
  to anyone else.

If you distribute a fork or a derived app, give it its own name, its own icon and its own
bundle identifier.

## Local content

The build can bundle content from an optional, gitignored `LocalOverlay/` folder — for example
recipes or artwork you hold rights to but may not redistribute. Nothing in that folder is part
of this repository, and you are responsible for the rights to whatever you put there.
