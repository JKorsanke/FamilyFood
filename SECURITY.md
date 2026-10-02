# Security Policy

## Supported versions

There are no releases yet. Only the latest commit on `main` is supported; fixes land there.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub's private vulnerability reporting: open this repository's **Security** tab and choose **Report a vulnerability**.

Do not open a public issue, pull request or discussion for a vulnerability.

## What to include

- A description of the issue and what an attacker could do with it.
- Steps to reproduce, or a proof of concept.
- The commit you tested, the iOS version, and whether you used a device or the simulator.
- Any suggestion for a fix, if you have one.

Remove API keys and personal data from anything you attach.

## What to expect

FamilyFood is a one-person project maintained in spare time. You can expect an acknowledgement within about a week. How quickly a fix follows depends on the severity and on the time the maintainer has; there is no guaranteed response or fix time.

## Scope notes

These points describe how the app handles data today, to help you judge a finding:

- The app has no backend. Recipes, meal plans, shopping lists and household settings are stored on the device only.
- The import features use the Anthropic API with the user's own API key, which the user enters in the app's Settings. The key is currently stored in `UserDefaults`, not in the Keychain. It therefore sits in the app's preferences file inside the app sandbox and is included in device backups. Moving it to the Keychain is a known open task.
- The app talks to `api.anthropic.com` for import parsing. It sends the text recognised on device from an imported meal plan or recipe, or the text of an imported web page, together with the API key.
- The app fetches recipe web pages the user chooses to import, and the recipe image such a page refers to.
- The share extension copies a shared link or file into the app's App Group container; the main app processes it later.

## Out of scope

- Issues that require a jailbroken device.
- Issues that require physical access to an unlocked device.
- Findings in third-party services, such as the Anthropic API or the websites a user imports from. Please report those to the respective provider.
