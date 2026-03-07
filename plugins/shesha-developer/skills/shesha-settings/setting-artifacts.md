# Setting Artifacts

## §1. Setting Name Constants

**File:** `{ModuleName}SettingNames.cs` in `Configuration/` (Domain project)

```csharp
namespace {ModuleNamespace}.Domain.Configuration
{
    /// <summary>
    /// Setting name constants for the {ModuleName} module.
    /// </summary>
    public class {ModuleName}SettingNames
    {
        /// <summary>
        /// {SimpleSettingDescription}
        /// </summary>
        public const string {SettingName} = "{SettingPrefix}.{ModuleName}.{SettingName}";

        /// <summary>
        /// {CompoundSettingDescription}
        /// </summary>
        public const string {CompoundSettingName} = "{SettingPrefix}.{ModuleName}.{CompoundSettingName}";
    }
}
```

**Key rules:**
- Use the module's root namespace as the `{SettingPrefix}` (e.g. `Shesha`, `SaGov`)
- One constants class per module — add new constants here as settings grow
- Name format: `"{Prefix}.{Module}.{Setting}"` — keeps names globally unique

---

## §2. Setting Accessor Interface

**File:** `I{ModuleName}Settings.cs` in `Configuration/` (Domain project)

```csharp
using Shesha.Settings;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace {ModuleNamespace}.Domain.Configuration
{
    [Category("{ModuleName}")]
    public interface I{ModuleName}Settings : ISettingAccessors
    {
        /// <summary>
        /// {SimpleSettingDescription}
        /// </summary>
        [Display(Name = "{Display Name}", Description = "{Description shown in Settings UI}")]
        [Setting({ModuleName}SettingNames.{SettingName})]
        ISettingAccessor<{PrimitiveType}> {SettingName} { get; set; }

        /// <summary>
        /// {CompoundSettingDescription}
        /// </summary>
        [Display(Name = "{Display Name}", Description = "{Description shown in Settings UI}")]
        [Setting({ModuleName}SettingNames.{CompoundSettingName}, EditorFormName = "{editor-form-name}")]
        ISettingAccessor<{CompoundClassName}> {CompoundSettingName} { get; set; }
    }
}
```

**Key rules:**
- One accessor interface per module — add new properties as settings grow
- Extends `ISettingAccessors`
- `[Category]` at interface level groups all settings; can also be per-property
- Simple settings use primitive `T`: `int`, `bool`, `string`, `decimal`, `DateTime`
- Compound settings use a custom class `T` and specify `EditorFormName`
- `EditorFormName` must match the name of a configurable form in Shesha UI

**Optional attributes:**
- `[Alias("camelCaseName")]` on the interface — overrides front-end group name
- `[Alias("camelCaseName")]` on a property — overrides front-end setting name

---

## §3. Compound Setting Class

**File:** `{CompoundClassName}.cs` in `Configuration/` (Domain project)

```csharp
namespace {ModuleNamespace}.Domain.Configuration
{
    /// <summary>
    /// {Description of what this group of settings controls}.
    /// </summary>
    public class {CompoundClassName}
    {
        /// <summary>
        /// {PropertyDescription}
        /// </summary>
        public {Type} {PropertyName} { get; set; }

        /// <summary>
        /// {PropertyDescription}
        /// </summary>
        public {Type} {PropertyName} { get; set; }
    }
}
```

**Key rules:**
- Plain POCO — no base class, no `virtual` keyword, no attributes
- Properties use standard C# types: `int`, `bool`, `string`, `decimal`, `DateTime`, `List<T>`
- Keep related values together in one class
- Property names become camelCase field names in the editor form (e.g. `DebitDay` -> `debitDay`)

---

## §4. Module Registration

Add setting registration to the module's `Initialize()` method. This goes in the **Application module** class (or the Domain module if no Application module exists).

**Simple setting registration:**

```csharp
public override void Initialize()
{
    var thisAssembly = Assembly.GetExecutingAssembly();
    IocManager.RegisterAssemblyByConvention(thisAssembly);

    // Register settings with default values
    IocManager.RegisterSettingAccessor<I{ModuleName}Settings>(x =>
    {
        x.{SettingName}.WithDefaultValue({defaultValue});
    });
}
```

**Compound setting registration:**

```csharp
IocManager.RegisterSettingAccessor<I{ModuleName}Settings>(x =>
{
    x.{SettingName}.WithDefaultValue({defaultValue});
    x.{CompoundSettingName}.WithDefaultValue(new {CompoundClassName}
    {
        {PropertyName} = {defaultValue},
        {PropertyName} = {defaultValue},
    });
});
```

**Key rules:**
- Call `RegisterSettingAccessor<T>` once per accessor interface
- Provide sensible default values for every setting
- Registration goes in `Initialize()` after `RegisterAssemblyByConvention`
- If the module already has `RegisterSettingAccessor`, add to the existing lambda
- The `using` for the Configuration namespace must be added to the module file
