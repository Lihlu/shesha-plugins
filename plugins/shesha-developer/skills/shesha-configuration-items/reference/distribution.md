# Distribution (Export/Import)

Three classes enable configuration item portability across environments.

## §1 Distribution DTO

Serializable representation of the configuration item. Lives in the `Distribution/` subfolder next to the entity in the Domain project (no `Dto/` subdirectory). Only includes serializable primitives — no entity references.

```csharp
using Shesha.ConfigurationItems.Distribution;
using System;

namespace {Namespace}.Domain.{ConfigName}s.Distribution
{
    public class Distributed{ConfigName} : DistributedConfigurableItemBase
    {
        // Mirror each custom property from the entity.
        // Use primitive types only (no entity references).

        // --- Scalar properties ---
        // public int? {IntProp} { get; set; }
        // public bool? {BoolProp} { get; set; }
        // public string {StringProp} { get; set; }

        // --- References to OTHER ConfigurationItem entities ---
        // IMPORTANT: Use Name + Module string pairs, NOT Guid IDs.
        // This is the established Shesha framework convention so that
        // exported packages are portable across environments where IDs differ.
        //
        // public string {Related}Name { get; set; }
        // public string {Related}Module { get; set; }

        // --- References to regular (non-config) entities ---
        // Use Guid? for FK references to ordinary entities.
        // public Guid? {RegularEntityId} { get; set; }

        // --- StoredFile properties ---
        // Serialize files as base64 so they are included in the export package.
        // For each StoredFile property on the entity, add three string properties:
        //
        // /// <summary>File name of the {description}</summary>
        // public string {PropName}FileName { get; set; }
        // /// <summary>MIME type of the {description}</summary>
        // public string {PropName}FileType { get; set; }
        // /// <summary>Base64-encoded content of the {description}</summary>
        // public string {PropName}Base64 { get; set; }
    }
}
```

The base `DistributedConfigurableItemBase` already includes: `Id`, `OriginId`, `Name`, `Label`, `ItemType`, `Description`, `ModuleName`, `FrontEndApplication`, `Suppress` and `BaseItem`. Declare only your own properties — the base ones are mapped for you in both directions.

## §2 Exporter

Derive from `ConfigurableItemExportBase<TItem, TDistributed>`. The framework maps every standard
property and owns JSON serialisation; you supply only the subclass properties.

### Interface

```csharp
using Shesha.ConfigurationItems.Distribution;

namespace {Namespace}.Domain.{ConfigName}s.Distribution
{
    public interface I{ConfigName}Export : IConfigurableItemExport<{ConfigName}>
    {
    }
}
```

### Implementation

```csharp
using Abp.Dependency;
using Shesha.ConfigurationItems.Distribution;
using System.Threading.Tasks;

namespace {Namespace}.Domain.{ConfigName}s.Distribution
{
    public class {ConfigName}Export
        : ConfigurableItemExportBase<{ConfigName}, Distributed{ConfigName}>,
          I{ConfigName}Export, ITransientDependency
    {
        public string ItemType => {ConfigName}.ItemTypeName;

        protected override Task MapCustomPropsAsync({ConfigName} item, Distributed{ConfigName} result)
        {
            // result.{CustomProp} = item.{CustomProp};

            // Cross-config-item reference - Name + Module, never the Guid:
            // result.{Related}Name   = item.{Related}?.Name;
            // result.{Related}Module = item.{Related}?.Module?.Name;

            return Task.CompletedTask;
        }
    }
}
```

Make `MapCustomPropsAsync` `async` when you need to await something — reading a `StoredFile`
stream, for example.

## §3 Importer

Derive from `ConfigurationItemImportBase<TItem, TDistributed>`. The framework finds the existing
item, resolves the module and front-end app, applies the revision status and deserialises the JSON.

### Interface

```csharp
using Shesha.ConfigurationItems.Distribution;

namespace {Namespace}.Domain.{ConfigName}s.Distribution
{
    public interface I{ConfigName}Import : IConfigurableItemImport<{ConfigName}>
    {
    }
}
```

### Implementation

```csharp
using Abp.Dependency;
using Abp.Domain.Repositories;
using Shesha.ConfigurationItems.Distribution;
using Shesha.Domain;
using Shesha.Services.ConfigurationItems;   // required for ConfigurationItemImportBase<,>
using System;
using System.Threading.Tasks;

namespace {Namespace}.Domain.{ConfigName}s.Distribution
{
    public class {ConfigName}Import
        : ConfigurationItemImportBase<{ConfigName}, Distributed{ConfigName}>,
          I{ConfigName}Import, ITransientDependency
    {
        public {ConfigName}Import(
            IRepository<Module, Guid> moduleRepo,
            IRepository<FrontEndApp, Guid> frontEndAppRepo,
            IRepository<{ConfigName}, Guid> repository
        ) : base(repository, moduleRepo, frontEndAppRepo)   // note the argument order
        {
        }

        public override string ItemType => {ConfigName}.ItemTypeName;

        /// <summary>
        /// Whether the stored item already matches the incoming one. Standard properties are
        /// compared by the base class - compare only your own here.
        /// </summary>
        protected override Task<bool> CustomPropsAreEqualAsync({ConfigName} item, Distributed{ConfigName} distributedItem)
        {
            var equal = true;
            // equal = item.{CustomProp} == distributedItem.{CustomProp};

            return Task.FromResult(equal);
        }

        protected override Task MapCustomPropsToItemAsync({ConfigName} item, Distributed{ConfigName} distributedItem)
        {
            // item.{CustomProp} = distributedItem.{CustomProp};

            return Task.CompletedTask;
        }

        /// <summary>
        /// Optional. Anything that must happen after the item itself is saved - child rows,
        /// stored files, calls into other services.
        /// </summary>
        protected override Task AfterImportAsync(
            {ConfigName} item,
            Distributed{ConfigName} distributedItem,
            IConfigurationItemsImportContext context)
        {
            return Task.CompletedTask;
        }
    }
}
```

### What changed in 0.46.0

The old importer was hand-rolled and no longer compiles. Deleting it is most of the work.

| Was your responsibility | Now |
|---|---|
| `ImportItemAsync(DistributedConfigurableItemBase, context)` | base class |
| Finding the existing row via `Name + Module + IsLast` | base class |
| Setting `VersionNo` / `VersionStatus` / `CreatedByImport` | gone — versioning is on revisions |
| Calling `Normalize()` | base class owns `Origin` |
| `ReadFromJsonAsync` / `WriteToJsonAsync` | base class |
| Mapping the standard properties | base class |

**`IsLast` has no replacement.** It existed only to pick the current row out of sibling version
rows; an item is now a single row with its versions in `ConfigurationItemRevision`. Delete the
predicate rather than looking for an equivalent — including in cross-config-item lookups.

**Watch the `using`.** Without `using Shesha.Services.ConfigurationItems;` the compiler reports
`ConfigurationItemImportBase<,>` as missing even though the assembly is referenced, because the
non-generic base of the same name lives elsewhere.

**Watch the constructor order.** The base takes `(repository, moduleRepo, frontEndAppRepo)` while
the conventional parameter order lists the module repo first — easy to transpose.

## Key Points

- **`ITransientDependency`** — both exporter and importer must implement this.
- **Item lookup, module resolution and revision status are the base class's job** — do not re-implement them.
- **`IsLast` no longer exists** — an item is a single row; delete the predicate rather than replacing it.
- **`Normalize()` is no longer yours to call** — the framework owns `Origin`.

### Cross-Config-Item References (IMPORTANT)

When a configuration item has a property that references **another ConfigurationItem entity** (e.g., a `SettingConfiguration` referencing an editor `FormConfiguration`, or an `EntityProperty` referencing a `ReferenceList`):

| Layer | What to do |
|-------|------------|
| **Distribution DTO** | Represent the reference as **two string properties**: `{Related}Name` and `{Related}Module`. Do NOT use `Guid?`. |
| **Exporter** | Map from the entity navigation property: `{Related}Name = entity.{Related}?.Name`, `{Related}Module = entity.{Related}?.Module?.Name`. |
| **Importer** | Resolve back to the entity using a `Name + Module` query (no `IsLast` — it no longer exists). |

**Why?** GUIDs are environment-specific — they differ between dev, staging, and production databases. Name + Module pairs are stable identifiers that make exported `.shaconfig` packages portable across environments.

**Framework examples** that follow this convention:
- `SettingExport` → exports `EditorFormName` / `EditorFormModule` (not FormConfiguration ID)
- `EntityConfigExport` → exports `ReferenceListName` / `ReferenceListModule` on entity properties (not ReferenceList ID)

**Exception — internal versioning GUIDs**: The base class properties `OriginId`, `BaseItem`, and `ParentVersionId` are exported as GUIDs because they track version lineage within the same item, not cross-references to different item types.

### StoredFile Properties (IMPORTANT)

When a configuration item has a `StoredFile` property (e.g., a document template, an uploaded image), the file content **must** be serialized into the export package so it can be recreated on import.

| Layer | What to do |
|-------|------------|
| **Distribution DTO** | Add three string properties per file: `{PropName}FileName`, `{PropName}FileType`, `{PropName}Base64`. |
| **Exporter** | Inject `IStoredFileService`. Read the file stream via `GetStreamAsync()`, copy to a `MemoryStream`, encode as `Convert.ToBase64String()`. |
| **Importer** | Inject `IStoredFileService`. Decode base64 to `byte[]`, wrap in `MemoryStream`, call `SaveFileAsync()` to create a new `StoredFile`, assign to the entity property. Set to `null` if base64 is empty. |

**Why?** StoredFile records are environment-specific database rows with file content stored in the configured blob provider. Without base64 serialization, imported configuration items would have broken file references.

## Exported Package Structure

Items are packaged into `.shaconfig` zip files with this folder structure:

```
{module-name}/
  {item-type-name}/            ← matches ItemTypeName
    {item-name}.json           ← one JSON file per item
```
