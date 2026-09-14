# Configuration Item Manager

The manager carries subclass-specific behaviour. Versioning lifecycle — copy, new revision, status transitions, move to module, delete — is owned entirely by the base class.

## Interface Template

```csharp
using Shesha.ConfigurationItems;

namespace {Namespace}.Domain.{ConfigName}s
{
    public interface I{ConfigName}Manager : IConfigurationItemManager<{ConfigName}>
    {
    }
}
```

## Implementation Template

```csharp
using Abp.Domain.Repositories;
using Shesha.ConfigurationItems;
using Shesha.Dto.Interfaces;
using System;
using System.Threading.Tasks;

namespace {Namespace}.Domain.{ConfigName}s
{
    public class {ConfigName}Manager
        : ConfigurationItemManager<{ConfigName}>, I{ConfigName}Manager
    {
        // No constructor unless you need extra repositories of your own.
        // The base class owns the item repository, the module repository and the
        // unit of work - do not inject or pass them.

        /// <summary>
        /// Copies the subclass properties when the framework duplicates an item or creates a
        /// new revision of it.
        /// </summary>
        protected override Task CopyItemPropertiesAsync({ConfigName} source, {ConfigName} destination)
        {
            // destination.{CustomProp} = source.{CustomProp};

            return Task.CompletedTask;
        }

        public override Task<IConfigurationItemDto> MapToDtoAsync({ConfigName} item)
        {
            var dto = ObjectMapper.Map<{ConfigName}ConfigItemDto>(item);
            return Task.FromResult<IConfigurationItemDto>(dto);
        }
    }
}
```

If the manager needs extra repositories, inject only those:

```csharp
public {ConfigName}Manager(IRepository<{ChildEntity}, Guid> itemRepository)
{
    _itemRepository = itemRepository;
}
```

## What changed in 0.46.0

Versioning moved onto `ConfigurationItemRevision`, and the manager surface shrank accordingly.

| Removed | Replacement |
|---------|-------------|
| `CopyAsync(item, CopyItemInput)` | `CopyItemPropertiesAsync(source, destination)` |
| `CreateNewVersionAsync(item)` | same — both collapse into the one method |
| Constructor injection of repository / module repo / UoW | base class owns them |

The two removed overrides were near-identical bodies that each constructed the new item by hand and set `Name`, `Module`, `Label`, `Description`, `VersionNo`, `VersionStatus`, `Origin` and `ParentVersion`. **The base class now owns all of that, including the identity of the copy.** It calls `CopyItemPropertiesAsync` to carry across the subclass properties, and nothing else.

So the body is a straight property-copy list. Do not set `Name`, `Module`, `Label`, `Description` or any versioning field — they no longer exist on the item, or are already handled.

`Normalize()` is likewise no longer yours to call: `Origin` is managed by the framework. Any `Normalize()` call in a manager or importer is a leftover from the pre-0.46 model and should be deleted.

## Inherited Methods (no override needed)

The base `ConfigurationItemManager<T>` provides:

| Method | Behavior |
|--------|----------|
| `UpdateStatusAsync(item, status)` | Validates revision status transitions, retires the previous live revision |
| `CancelVersionAsync(item)` | Cancels the current revision |
| `MoveToModuleAsync(item, input)` | Moves the item to a new module, validates uniqueness |
| `DeleteAllVersionsAsync(item)` | Soft-deletes the item and its revisions |

## Migrating an existing manager

1. Delete the constructor unless it injects something beyond the three base dependencies.
2. Delete `CopyAsync` and `CreateNewVersionAsync`; keep only the custom-property assignments from either one — they were duplicates of each other.
3. Put those assignments in `CopyItemPropertiesAsync(source, destination)`.
4. Delete every reference to `VersionNo`, `VersionStatus`, `ParentVersion`, `Origin` and `Normalize()`.
5. Drop the `using Shesha.Domain.ConfigurationItems;` and `using Shesha.ConfigurationItems.Models;` lines — both namespaces are gone from this path.
