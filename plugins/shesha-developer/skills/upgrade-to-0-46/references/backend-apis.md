# Backend API Migration

Phase 2. Expect a **cascade**: each project you fix lets the next one compile and reveal its own errors. Five rounds is normal. Do not estimate from the first error count.

## §1. Configuration Items rewrite

`ConfigurationItemBase` → `ConfigurationItem`, and versioning moved onto `ConfigurationItemRevision`. `VersionNo`, `VersionStatus`, `ParentVersion`, `Origin` and `IsLast` are gone from the item.

### Entity

```csharp
// remove: using Shesha.Domain.ConfigurationItems;
public class {Item} : ConfigurationItem          // was ConfigurationItemBase
{
    public const string ItemTypeName = "{slug}";
    public override string ItemType => ItemTypeName;
    // delete the ctor / Init() that set VersionStatus
}
```

### Manager

`CopyAsync(item, CopyItemInput)` and `CreateNewVersionAsync(item)` both disappear, replaced by one method. The old pair were near-identical bodies that each built the new item by hand and set `Name`/`Module`/`Label`/`VersionNo`/`VersionStatus`/`Origin`/`ParentVersion`; the base class owns all of that now — and owns the repositories, so the constructor injection goes too.

```csharp
public class {Item}Manager : ConfigurationItemManager<{Item}>, I{Item}Manager
{
    // no ctor unless you need extra repositories

    protected override Task CopyItemPropertiesAsync({Item} source, {Item} destination)
    {
        destination.{Prop} = source.{Prop};   // subclass properties only
        return Task.CompletedTask;
    }

    public override Task<IConfigurationItemDto> MapToDtoAsync({Item} item) { ... }
}
```

### Export / Import

```csharp
public class {Item}Export
    : ConfigurableItemExportBase<{Item}, Distributed{Item}>, I{Item}Export, ITransientDependency
{
    public string ItemType => {Item}.ItemTypeName;
    protected override Task MapCustomPropsAsync({Item} item, Distributed{Item} result) { ... }
}

public class {Item}Import
    : ConfigurationItemImportBase<{Item}, Distributed{Item}>, I{Item}Import, ITransientDependency
{
    public {Item}Import(
        IRepository<Module, Guid> moduleRepo,
        IRepository<FrontEndApp, Guid> frontEndAppRepo,
        IRepository<{Item}, Guid> repository
    ) : base(repository, moduleRepo, frontEndAppRepo) { }   // note the argument order

    public override string ItemType => {Item}.ItemTypeName;
    protected override Task<bool> CustomPropsAreEqualAsync({Item} item, Distributed{Item} d) { ... }
    protected override Task MapCustomPropsToItemAsync({Item} item, Distributed{Item} d) { ... }
    protected override Task AfterImportAsync({Item} item, Distributed{Item} d, IConfigurationItemsImportContext ctx) { ... }
}
```

**Key rules:**
- The import base needs `using Shesha.Services.ConfigurationItems;` — without it `ConfigurationItemImportBase<,>` appears missing even though the assembly is referenced.
- The framework now owns item lookup, module resolution, `Normalize()` and JSON serialisation. Delete all of it, including any hand-written `IsLast` query.
- `IsLast` has **no replacement**. It existed only to pick the current row out of sibling version rows; an item is now a single row. Delete the predicate rather than seeking an equivalent, and delete tests that stage superseded siblings — they test a model that no longer exists.
- The `Distributed{Item}` DTO usually needs no change: it declares only custom properties, and the base populates the standard ones.

## §2. Abp 10.3 — `GetAll()` is awaitable

`VSTHRD103` is promoted to an error by `.editorconfig`, so every synchronous `GetAll()` fails the build. Expect 50–100 sites.

**Wrap in place. Do not move the `await`.**

```csharp
X.GetAll()  →  (await X.GetAllAsync())
```

Wrapping preserves any existing outer `await`. *Moving* it silently breaks code that ends in `FirstOrDefaultAsync()`:

```csharp
// WRONG - the variable is now a Task, and .Id resolves to Task.Id (an int)
var m = (await repo.GetAllAsync()).Where(...).FirstOrDefaultAsync();

// RIGHT - both awaits
var m = await (await repo.GetAllAsync()).Where(...).FirstOrDefaultAsync();
```

The compiler catches it only if the result is used in a type-checked position. Two shapes need care:

- **Multiline chains** where `.GetAll()` sits on its own line — the receiver is on the line above; merge them.
- **Methods returning `Task<T>` directly** (no `async`) — add `async` and `return await`.

## §3. Removed and changed APIs

| Was | Now |
|---|---|
| `SendNotificationAsync(..., priority: ...)` | `priority` parameter removed |
| `ShaRoleAppointmentEntity` | removed — usually injected but never read; drop the dependency |
| `Shesha.Web.FormsDesigner.Domain` namespace | gone; `NotificationMessage` via `Shesha.Html.Tools.Message` |
| `protected override void Convert(TextWriter, object)` | log4net widened `PatternConverter.Convert` to `public`; an override cannot narrow |
| `AsyncHelper.RunSync` | still exists, but needs `using Abp.Threading;` |

**Key rules:**
- Before remapping a removed type, check whether it is actually *used*. `ShaRoleAppointmentEntity` repositories are typically assigned in a constructor and never read — delete rather than substitute.
- Some errors are masked until a blocking project compiles. Rebuild the whole solution after each fix rather than assuming the count is stable.

## §4. Projects outside the .sln

`dotnet build <solution>` reporting 0 errors does **not** mean the backend is clean. Enumerate projects on disk and diff against the solution:

```bash
find . -name '*.csproj' -not -path '*/obj/*' | sort > /tmp/all.txt
grep -oE '[A-Za-z0-9_.\\]+\.csproj' *.sln | tr '\\' '/' | sort -u > /tmp/insln.txt
comm -23 /tmp/all.txt /tmp/insln.txt
```

Test projects are the usual omission. Run them too — a test asserting removed behaviour is a real signal, not noise.
