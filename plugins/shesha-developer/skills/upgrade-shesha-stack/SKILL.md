---
name: upgrade-shesha-stack
description: Upgrades Shesha framework dependencies in both frontend and backend projects to a specified version. Handles monorepo and standard project structures. Use when user wants to upgrade, update, or migrate Shesha versions.
---

# Upgrade Shesha Stack

Upgrade Shesha framework dependencies to a specified version across frontend (React) and backend (.NET) projects.

## Instructions

This skill performs a coordinated upgrade of Shesha dependencies across your entire stack:

1. **Ask for target Shesha version** using AskUserQuestion
2. **Upgrade frontend** packages in `/adminportal` folder (including `@shesha-io/enterprise`)
3. **Upgrade backend** packages in `/backend` folder
4. **Verify and report** all changes made

### Key Rules

- Always ask user for target Shesha version before proceeding
- Use the same version for both frontend and backend
- Frontend: Update `@shesha-io/enterprise` first, then other `@shesha-io/*` packages
- Backend: Only modify `directory.build.props`, never individual `.csproj` files
- Handle both monorepo (with `packages/` subfolder) and standard structures
- Check for package-lock.json or yarn.lock to determine package manager
- Report all version changes clearly

## Workflow

### Step 1: Ask for Target Shesha Version

Use `AskUserQuestion` to get the desired Shesha version:

```
What Shesha version would you like to upgrade to?
Example: 3.1.0, 3.2.0, etc.
```

This version will be applied to both frontend and backend.

### Step 2: Upgrade Frontend Dependencies

**Location:** `/adminportal` folder

1. **Find all package.json files:**
   - Main: `adminportal/package.json`
   - Subprojects: `adminportal/packages/*/package.json` (if exists)

2. **Update `@shesha-io/enterprise`:**
   - Set to the target Shesha version from Step 1
   - Example: `"@shesha-io/enterprise": "3.1.0"`
   - **Note:** `@shesha-io/enterprise` is the main package for Shesha projects

3. **Update other `@shesha-io/*` packages:**
   - Find all dependencies starting with `@shesha-io/`
   - Update to the same target version or compatible versions
   - Check npm registry or use `npm view @shesha-io/{package} peerDependencies` if needed

4. **Determine package manager:**
   - If `package-lock.json` exists → npm
   - If `yarn.lock` exists → yarn
   - If `pnpm-lock.yaml` exists → pnpm

5. **Run update command** (after asking user for permission):
   - npm: `npm install`
   - yarn: `yarn install`
   - pnpm: `pnpm install`

**Packages to update (typical list):**
- `@shesha-io/enterprise` (main enterprise framework)
- `@shesha-io/reactjs` (if present, update to compatible version)
- `@shesha-io/pd-publicholidays`
- `@shesha-io/pd-core`
- Any other `@shesha-io/*` packages found

### Step 3: Upgrade Backend Dependencies

**Location:** `/backend` folder

1. **Find directory.build.props:**
   - Path: `backend/directory.build.props`
   - This file contains centralized version management for all NuGet packages
   - Reference: See `plugins/shesha-developer/skills/create-module/reference/ProjectFiles.md` for structure

2. **Update Shesha version property:**
   - Look for property like `<SheshaVersion>X.X.X</SheshaVersion>`
   - Update to the same target Shesha version from Step 1
   - Example: `<SheshaVersion>3.1.0</SheshaVersion>`

3. **Update Shesha and Boxfusion package references:**
   - Find all `<PackageReference>` elements with `Include` or `Update` starting with:
     - `Shesha.*`
     - `Boxfusion.*`
   - Ensure they reference `$(SheshaVersion)` variable
   - **IMPORTANT:** Only modify versions in `directory.build.props`, NOT in `.csproj` files

4. **Common packages to update:**
   - `Shesha.Application` Version="$(SheshaVersion)"
   - `Shesha.Core` Version="$(SheshaVersion)"
   - `Shesha.Framework` Version="$(SheshaVersion)"
   - `Shesha.NHibernate` Version="$(SheshaVersion)"
   - `Boxfusion.*` packages (if present)

**Example directory.build.props structure:**

```xml
<Project>
  <PropertyGroup>
    <SheshaVersion>3.1.0</SheshaVersion>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Update="Shesha.Application" Version="$(SheshaVersion)" />
    <PackageReference Update="Shesha.Core" Version="$(SheshaVersion)" />
    <PackageReference Update="Shesha.Framework" Version="$(SheshaVersion)" />
    <PackageReference Update="Shesha.NHibernate" Version="$(SheshaVersion)" />
  </ItemGroup>
</Project>
```

### Step 4: Verify and Report

After making changes:

1. **List all files modified:**
   - Frontend package.json files updated
   - Backend directory.build.props updated

2. **Show version changes:**
   - Before → After for each package
   - Format: `@shesha-io/enterprise: 0.42.0 → 3.1.0`
   - Show the Shesha version used for both frontend and backend

3. **Recommend next steps:**
   - Run `npm install` (if not already run)
   - Run `dotnet restore` in backend
   - Test the application
   - Review breaking changes in Shesha release notes

## Quick Reference

### Frontend Files to Update

| File | Purpose | Pattern |
|------|---------|---------|
| `adminportal/package.json` | Main frontend dependencies | `@shesha-io/*` packages, especially `@shesha-io/enterprise` |
| `adminportal/packages/*/package.json` | Monorepo subprojects | `@shesha-io/*` packages |

### Backend Files to Update

| File | Purpose | Pattern |
|------|---------|---------|
| `backend/directory.build.props` | Centralized NuGet versions | `Shesha.*`, `Boxfusion.*` with `$(SheshaVersion)` |

### Version Property Patterns

**Frontend (package.json):**
```json
{
  "dependencies": {
    "@shesha-io/enterprise": "3.1.0",
    "@shesha-io/reactjs": "3.1.0",
    "@shesha-io/pd-publicholidays": "^3.1.0"
  }
}
```

**Backend (directory.build.props):**
```xml
<PropertyGroup>
  <SheshaVersion>3.1.0</SheshaVersion>
</PropertyGroup>
<ItemGroup>
  <PackageReference Update="Shesha.Application" Version="$(SheshaVersion)" />
  <PackageReference Update="Shesha.Core" Version="$(SheshaVersion)" />
  <PackageReference Update="Shesha.Framework" Version="$(SheshaVersion)" />
  <PackageReference Update="Shesha.NHibernate" Version="$(SheshaVersion)" />
</ItemGroup>
```

**Note:** Both frontend and backend use the same Shesha version (e.g., 3.1.0).

## Safety Checks

Before proceeding:
- [ ] Backup current versions (or ensure git is clean)
- [ ] Verify target Shesha version exists on npm and NuGet
- [ ] Check for breaking changes in Shesha release notes
- [ ] Ensure no uncommitted changes (recommend `git status`)

After upgrading:
- [ ] Run `npm install` / `yarn install` in adminportal
- [ ] Run `dotnet restore` in backend
- [ ] Check for compilation errors
- [ ] Run tests if available
- [ ] Verify `@shesha-io/enterprise` is properly installed

## Error Handling

**If version not found on npm or NuGet:**
- Inform user that the version doesn't exist
- Ask user to confirm the correct version number
- Check available versions: `npm view @shesha-io/enterprise versions` or NuGet package page

**If package.json not found:**
- Verify `/adminportal` path exists
- Check if frontend is in different location

**If directory.build.props not found:**
- Verify `/backend` path exists
- Check if using different versioning strategy
- Look for individual `.csproj` files (warn user about manual update needed)

**If version mismatch errors:**
- Check peer dependencies
- Verify version compatibility
- Suggest using exact versions instead of ranges

## Example Usage

**User request:** "Upgrade to Shesha version 3.1.0"

**Workflow:**
1. Ask: "Confirm upgrade to Shesha version 3.1.0?"
2. Update `adminportal/package.json`: `@shesha-io/enterprise: "3.1.0"`
3. Update other `@shesha-io/*` packages to compatible versions
4. Update `backend/directory.build.props`: `<SheshaVersion>3.1.0</SheshaVersion>`
5. Report changes and recommend testing

## Important Notes

- The same version is used for both frontend (`@shesha-io/enterprise`) and backend (`SheshaVersion`)
- This ensures consistency across the entire stack
- Always verify the version exists on both npm and NuGet before upgrading

Now perform the upgrade based on user's requirements.
