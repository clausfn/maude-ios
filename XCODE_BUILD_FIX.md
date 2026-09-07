# Maude — Xcode build fix (read this if Build fails)

The project **builds successfully** from the command line. If Xcode still shows errors, follow these steps **in order**.

## 1. Open the correct project

```
09_Maude_iOS_Prototype/Maude/Maude/Maude.xcodeproj
```

Do **not** open the older folder `09_Maude_iOS_Prototype/Maude/` (no `.xcodeproj` there).

## 2. Reset Xcode caches

1. Quit Xcode
2. In Terminal:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Maude-*
```

3. Reopen `Maude.xcodeproj`

## 3. Remove Supabase package (if Xcode added it back)

1. Project navigator → click **Maude** (blue icon)
2. **Package Dependencies** tab
3. If **supabase-swift** or **swift-algorithms** appear → select → **−** Remove
4. **File → Packages → Reset Package Caches**

The app runs in **Demo mode** without Supabase.

## 4. Pick the right destination

Top toolbar, next to the scheme:

- ✅ **iPhone 17** (or any iPhone Simulator)
- ✅ Your **iPhone** (physical device, iOS 17+)
- ❌ **My Mac**
- ❌ **DeadpoolNet-iPad** if iOS is below 17

## 5. Signing (physical device only)

1. Target **Maude** → **Signing & Capabilities**
2. **Team:** choose your Apple ID team
3. If you see “requires a development team” — this is signing, not code. Add a team.

## 6. Clean build

1. **Product → Clean Build Folder** (⇧⌘K)
2. **Product → Build** (⌘B)

## 7. Verify from Terminal (optional)

```bash
cd "/Users/claus/Documents/Claude/Projects/Maude/09_Maude_iOS_Prototype/Maude/Maude"
./build-ios.sh
```

You should see `BUILD SUCCEEDED`.

## Still failing?

Copy the **first red line** from Xcode’s Issue navigator (⚠️ left sidebar) and send it. Examples:

- `Cannot find type 'UUID' in scope` → old Supabase file; pull latest repo changes
- `Signing for "Maude" requires a development team` → step 5
- `iOS 26.x doesn't match deployment target` → pick a simulator or lower device OS
