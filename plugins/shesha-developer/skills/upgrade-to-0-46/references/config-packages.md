# Config packages (`.shaconfig`)

Form configuration shipped in the repo is the fourth failure class, and the least visible. These
defects survive a clean build, a successful start-up and a green migration run. They are found by a
person looking at a screen.

---

## §1. Reading a `.shaconfig`

A `.shaconfig` is a ZIP of configuration items. Three details are easy to get wrong, and each one
silently yields zero results rather than an error:

- form entries live at `<ModuleName>/form/<name>.json` inside the archive;
- the markup key is **`Markup`** — PascalCase. A lowercase guess finds nothing;
- `Markup` is sometimes a JSON **string** that needs a second parse.

Walk components recursively: children hang off `components`, and containers nest.

---

## §2. Container layout is flattened, and the damage is in the database

**Symptom.** A horizontal container renders stacked after the upgrade — children full width, gap
gone, row reading as a column. Nothing errors.

**Cause.** The breakpoint block ends up `display: block`, or with no `display` at all, while still
carrying `justifyContent`, `gap`, `flexWrap` and sometimes `alignItems`. Those do nothing without
`display: flex`, so the intent survives in the config while the layout does not.

**Fix.** Set `display: flex` on the affected breakpoint block, keeping the existing gap and
justification.

### Where it actually hurts

**The upgrade writes the flattened blocks into the database copy of the form, not into the package
in the repo.** Consequences, in order of how much time each costs:

- The shipped package is usually *clean*. Reading it proves nothing about what the app renders.
- A developer who fixes the layout in the designer has fixed it **only in their own database**. On
  a fresh database the old package re-imports and the spacing is lost again.
- Re-exporting a form moves a fix into the repository — **and is also how the damage spreads**,
  because a form exported from an upgraded designer carries whatever the designer currently holds.

So: **fix the form, re-export it, commit the new package** — in that order. A layout fix that lives
only in a database is not a fix, and a package exported from an unrepaired form propagates the
defect to every environment that imports it.

### Scanning for it

For each `type === 'container'`, inspect each of `desktop` / `tablet` / `mobile`. Flag the block if
it carries any of `justifyContent`, `flexDirection`, `gap`, `alignItems`, `flexWrap` **and**
`display` is anything other than `flex` (including absent).

Calibration from one host app: **136 flagged blocks across 12 form entries** — `display: block` in
the majority, unset in the rest. The same sweep found **no** hits for the generic layout checks
(dimension overflow, top-level `dimensions`, `style.width` conflicts), so those are not a
substitute. A package passes every generic check and still renders flattened.

Two style generations coexist in the same packages, which is worth knowing before concluding
anything from a sample: legacy `className` / `stylingBox` / `style`-as-string, versus the newer
per-breakpoint `dimensions` / `border` / `background` / `font` / `shadow` blocks. Only forms
re-saved since the style model changed carry the latter.

---

## §3. `selectedRow` is scoped to the data context

**The change.** `selectedRow` and `selectedItem` resolve **only inside the data context** that owns
them — the table, list or picker and its descendants.

**Symptom.** Silence. An outside reference resolves to `undefined`, so a visibility expression
returns false and the component never appears, a query parameter goes out empty, a button stays
disabled. Nothing throws.

**Fix — publish the selection into form data.**

1. In the data component's select handler — `onSelect`, `onItemSelect`, or whatever that component
   calls it; the name varies, so read the component's own settings rather than assuming:

   ```js
   form.setFieldValue('dtxSelectValue', value);
   ```

2. Point every outside reader at that form-data variable instead of `selectedRow`.

One variable name per data context, kept stable — outside readers are usually spread across several
components and must all agree.

### Finding the out-of-context reads

Track data-context ancestry while walking the tree; a `selectedRow` / `selectedItem` string found
while **not** inside one is a break. Three access shapes count, and searching for one misses the
others:

| Shape | Example |
|---|---|
| bare identifier | `` `/dynamic/.../details?id=${selectedRow?.id}` `` |
| via global state, by context name | `globalState.<contextName>.selectedRow?.id` |
| mustache | `{{globalState.<contextName>.selectedRow.id}}` |

They hide in scriptable properties — measured frequency: `_code`, `expression`, `queryParams`,
`value`, `customVisibility`, `customEnabled`. Search property *values* generically rather than
working from a fixed list of names.

**Watch `_code`.** An earlier framework migration wrapped old expressions instead of rewriting
them, leaving bodies that open `// Automatically updated from 'customVisibility', please review`
with the original source preserved inside. Stale references survive there unreviewed, under a
property name that no longer matches what the designer shows. In one host app that accounted for 79
of 200 out-of-context references.

Calibration: **1,181 in-context references — all fine — against 200 out-of-context across 14 form
entries.** The ratio is the point. A scan that does not distinguish inside from outside returns
~1,400 hits and is unusable.

---

## §4. A framework-owned form loses local customisations

A form owned by a framework module is rewritten with an empty revision on every boot, so any
component an app added to it is dropped from the effective configuration after the upgrade.

Restoring the pre-upgrade revision is the wrong instinct — it also reverts the new design. Instead:
expose the form into a module the app owns, re-apply the customisation on top of the new version,
and ship that as a config package. Otherwise a fresh database renders the framework's version and
the customisation disappears again.

---

## §5. Shipping the fix

Changed forms go out as a **new** package, never by editing an existing one in place.

An existing package is a historical record that has already been applied: rewriting it does not
re-run it, and the edit is lost at the next export. Generate a new package carrying the changed
forms and register it alongside the others.

**Key rules:**
- Anything corrected only in a database is not corrected. It must reach a package.
- Re-export is the delivery mechanism *and* the contamination mechanism — never re-export a form
  you have not checked.
- One host app can hold 150+ packages and ~850 form entries. Report findings per form entry and per
  package, not as a flat list.
