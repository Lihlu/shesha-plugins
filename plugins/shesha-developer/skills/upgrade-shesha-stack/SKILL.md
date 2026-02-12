---
name: upgrade-shesha-stack
description: Upgrades Shesha framework dependencies in both frontend and backend projects to a specified version. Handles monorepo and standard project structures. Use when user wants to upgrade, update, or migrate Shesha stack versions.
---

# Upgrade Shesha Stack

Upgrade Shesha framework dependencies to a specified version across frontend (React) and backend (.NET) projects.

## Instructions

This skill performs a coordinated upgrade of Shesha dependencies across your entire stack:

1. **Ask for target version** using AskUserQuestion
2. **Upgrade frontend** packages in `/adminportal` folder
3. **Upgrade backend** packages in `/backend` folder
4. **Verify and report** all changes made

### Key Rules

- Always ask user for target Shesha version before proceeding
- Frontend: Update `@shesha-io/reactjs` first, then other `@shesha-io/*` packages
- Backend: Only modify `directory.build.props`, never individual `.csproj` files
- Handle both monorepo (with `packages/` subfolder) and standard structures
- Check for package-lock.json or yarn.lock to determine package manager
- Report all version changes clearly

## Workflow

### Step 1: Ask for Target Version

Use `AskUserQuestion` to get the desired Shesha version:

```
What Shesha version would you like to upgrade to?
Example: 0.43.3
```

### Step 2: Upgrade Frontend Dependencies

**Location:** `/adminportal` folder

1. **Find all package.json files:**
   - Main: `adminportal/package.json`
   - Subprojects: `adminportal/packages/*/package.json` (if exists)

2. **Update `@shesha-io/reactjs`:**
   - Set to the exact target version specified by user
   - Example: `"@shesha-io/reactjs": "0.43.3"`

3. **Update other `@shesha-io/*` packages:**
   - Find all dependencies starting with `@shesha-io/`
   - Update to latest compatible versions that support the target `@shesha-io/reactjs` version
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
- `@shesha-io/reactjs` (main framework)
- `@shesha-io/pd-publicholidays`
- `@shesha-io/pd-core`
- Any other `@shesha-io/*` packages found

### Step 3: Upgrade Backend Dependencies

**Location:** `/backend` folder

1. **Find directory.build.props:**
   - Path: `backend/directory.build.props`
   - This file contains centralized version management for all NuGet packages

2. **Update Shesha version property:**
   - Look for property like `<SheshaVersion>X.X.X</SheshaVersion>`
   - Update to target version
   - Example: `<SheshaVersion>0.43.3</SheshaVersion>`

3. **Update Shesha and Boxfusion package references:**
   - Find all `<PackageReference>` elements with `Include` starting with:
     - `Shesha.*`
     - `Boxfusion.*`
   - Update their `Version` attribute to match target version or latest compatible
   - **IMPORTANT:** Only modify versions in `directory.build.props`, NOT in `.csproj` files

4. **Common packages to update:**
   - `Shesha.Core`
   - `Shesha.Framework`
   - `Shesha.NHibernate`
   - `Shesha.Application`
   - `Shesha.Web.ForMvc`
   - `Boxfusion.*` packages (if present)

**Example directory.build.props structure:**

```xml
<Project>
  <PropertyGroup>
    <SheshaVersion>0.43.3</SheshaVersion>
  </PropertyGroup>

  <ItemGroup>
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
   - Format: `@shesha-io/reactjs: 0.42.0 → 0.43.3`

3. **Recommend next steps:**
   - Run `npm install` (if not already run)
   - Run `dotnet restore` in backend
   - Test the application
   - Review breaking changes in release notes

## Quick Reference

### Frontend Files to Update

| File | Purpose | Pattern |
|------|---------|---------|
| `adminportal/package.json` | Main frontend dependencies | `@shesha-io/*` packages |
| `adminportal/packages/*/package.json` | Monorepo subprojects | `@shesha-io/*` packages |

### Backend Files to Update

| File | Purpose | Pattern |
|------|---------|---------|
| `backend/directory.build.props` | Centralized NuGet versions | `Shesha.*`, `Boxfusion.*` |

### Version Property Patterns

**Frontend (package.json):**
```json
{
  "dependencies": {
    "@shesha-io/reactjs": "0.43.3",
    "@shesha-io/pd-publicholidays": "^0.43.0"
  }
}
```

**Backend (directory.build.props):**
```xml
<PropertyGroup>
  <SheshaVersion>0.43.3</SheshaVersion>
</PropertyGroup>
<ItemGroup>
  <PackageReference Update="Shesha.Core" Version="$(SheshaVersion)" />
</ItemGroup>
```

## Safety Checks

Before proceeding:
- [ ] Backup current versions (or ensure git is clean)
- [ ] Verify target version exists on npm and NuGet
- [ ] Check for breaking changes in release notes
- [ ] Ensure no uncommitted changes (recommend `git status`)

After upgrading:
- [ ] Run `npm install` / `yarn install` in adminportal
- [ ] Run `dotnet restore` in backend
- [ ] Check for compilation errors
- [ ] Run tests if available

## Error Handling

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

**User request:** "Upgrade Shesha to version 0.43.3"

**Workflow:**
1. Ask: "Confirm upgrade to Shesha 0.43.3?"
2. Update `adminportal/package.json`: `@shesha-io/reactjs: "0.43.3"`
3. Update `backend/directory.build.props`: `<SheshaVersion>0.43.3</SheshaVersion>`
4. Report changes and recommend testing

Now perform the upgrade based on user's requirements.
