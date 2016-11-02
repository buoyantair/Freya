--//
--// * Hearth for Freya
--// | Package manager for Freya.
--//

ni = newproxy true

local InstallPackage, UpdatePackage, UninstallPackage, GetPackage

Hybrid = (f) -> (...) ->
  return f select 2, ... if ... == ni else f ...

Locate = (Type) ->
  return switch Type
    when 'ServerScript' then game.ServerScriptService.Freya
    when 'PlayerScript' then game.StarterPlayer.StarterPlayerScripts.Freya
    when 'ReplicatedFirst' then game.ReplicatedFirst.Freya
    when 'SharedComponent' then game.ReplicatedStorage.Freya.Components.Shared
    when 'ClientComponent' then game.ReplicatedStorage.Freya.Components.Client
    when 'ServerComponent' then game.ServerStorage.Freya.Components
    when 'Library' then game.ReplicatedStorage.Freya.Libraries
    when 'LiteLibrary' then game.ReplicatedStorage.Freya.LiteLibraries
    when 'Util' then game.ServerStorage.Freya.Util
    else error "Invalid Type for package!", 3
    
PackageModule = script.Parent.Parent.PackageList
Packages = require PackageModule
Flush = ->
  PackageModule\Destroy!
  Buffer = {'{'}
  for Package in *Packages
    Buffer[#Buffer+1] = "{
Resource = #{Package.Resource\GetFullName!\gsub '^([^%.%[]+)', 'game:GetService(\'%1\')'};
Origin = {
  Name = '#{Package.Origin.Name}';
  Type = '#{Package.Origin.Type}';
  Version = '#{Package.Origin.Version}';
}
};
"
  Buffer[#Buffer+1] = '}'
  PackageModule = with Instance.new("ModuleScript")
    .Source = table.concat Buffer, ''
    .Name = 'PackageList'
    .Parent = script.Parent.Parent
    
ResolveVersion = Hybrid (Version) ->
    i,j,branch,major,minor,patch = Version\find("^(%a+)%.(%d+)%.?(%d*)%.?(%d*)$")
    if i
      return {
        :branch
        major: tonumber major
        minor: tonumber minor
        patch: tonumber patch
      }
    else
      warn "Unusual version format."
      i,j,major,minor,patch = Version\find(^(%d+)%.?(%d*)%.?(%d*)$)
      if i
        return {
          major: tonumber major
          minor: tonumber minor
          patch: tonumber patch
        }
      else
        warn "Uncomparable version format. Assuming simply major version."
        major: major

ResolvePackage = Hybrid (Package, Version) ->
    switch type Package
      when 'number'
      -- AssetId for package.
      -- Versions are irrelevant.
      s, package = pcall -> game\GetService"InsertService"\LoadAsset Package
      return nil, "Unable to get package: #{package}" unless s
      s, package = pcall require, package
      return nil, "Unable to require package: #{package}" unless s
      return nil, "Package does not return a table" unless type(package) == 'table'
      return package
      when 'string'
        --  Determine protocol
        switch Package\match '^(%w):'
          when 'github'
            -- Github-based package.
            -- No extended support (Scripts only)
            -- Count the path
            switch select 2, Package\gsub('/', '')
              when 2
                -- Repo is package
              when 3
                -- Repo is package repo; Get defs from repo
              else
                return nil, "Invalid Github package protocol"
          when 'freya'
            -- Freya-based package.
            -- No Freya APIs available for getting this data yet
          else
            -- Unknown protocol or no protocol.
            -- Assume Freya packages or Github packages.
            -- Check existing package repo list.
      when 'userdata'
        -- We'll assume it's a ModuleScript already. No version check.
        s, err = pcall require, Package
        return nil, "Unable to load package: #{err}" unless s
        return nil, "Package does not return a table" unless type(s) == 'table'
        return err
      when 'table'
        -- It's a boy! No version check.
        return Package
      else
        return nil, "Invalid package format."

CompareVersions = (v1, v2) ->
  v1 = ResolveVersion v1.Version
  v2 = ResolveVersion v2.Version
  check = true
  if v1.branch and v2.branch ~= v1.branch
    check = false
  if v1.major
    if type(v1.major) == 'string'
      -- Uncomparable. Check equality.
      unless v1.major == v2.major
        check = false
    elseif v1.major > v2.major
      check = false
  if (v1.major == v2.major) and v1.minor and v2.minor and (v1.minor > v2.minor)
    check = false
    if (v1.minor == v2.minor) and v1.patch and v2.patch and (v1.patch > v2.patch)
      check = false
  check

Hearth = {
  InstallPackage: Hybrid (Package, Version, force) ->
    -- Will invoke Update too, but also installs.
    apkg = Package
    -- Resolve the package
    Package, err = ResolvePackage Package
    return error "[Error][Freya Hearth] Unable to install package: \"#{err}\"", 2 unless Package
    with Package
      assert .Type,
        "[Error][Freya Hearth] Package file does not include a valid type for the package.",
        2
      unless .Package
        assert .Name,
          "[Error][Freya Hearth] Package has no name or package origin.",
          2
        .Package = apkg\FindFirstChild Name
        assert .Package,
          "[Error][Freya Hearth] Package origin is invalid.",
          2
      unless .Version
        warn "[Warn][Freya Hearth] No package version. Treating the package as version 1"
        .Version = 'initial.0'
      if .Depends
        for dep in *.Depends
          -- Origin
          -- Name
          -- Version
          return error "[Error][Freya Hearth] Malformed dependency list" unless 
          pak = GetPackage dep.Name
          if pak -- If it's installed
            if dep.Version
              -- Check that the version is alright
              clear = CompareVersions dep.Version, pak.Version
              unless clear -- Failed dep version
                warn "[Warn][Freya Hearth] Incomplete dependency #{dep.Name} #{dep.Version}. Attempting to install."
                s, err = pcall InstallPackage dep.Origin or dep.Name, dep.Version
                return error "[Error][Freya Hearth] Failed to install dependency #{dep.Name} #{dep.Version} because \"#{err}\"", 2 unless s
                print "[Info][Freya Hearth] Installed dependency #{dep.Name} #{dep.Version}"
            else
              warn "[Warn][Freya Hearth] dependency #{dep.Name} has no version specified. Be warned that it may not function."
              -- No need to install anything else.
          else
            -- Try to install the package.
            warn "[Warn][Freya Hearth] Missing dependency #{dep.Name} #{dep.Version or 'latest'}. Attempting to install."
            s, err = pcall InstallPackage dep.Origin or dep.Name, dep.Version
            return error "[Error][Freya Hearth] Failed to install dependency #{dep.Name} #{dep.Version} because \"#{err}\"", 2 unless s
            print "[Info][Freya Hearth] Installed dependency #{dep.Name} #{dep.Version or 'latest'}"
      pkgloc = Locate .Type
      opkg = pkgloc\FindFirstChild .Package.Name
      if opkg
        if .Update and force 
          .Update opkg, .Package
          warn "[Warn][Freya Hearth] Updating #{.Name or .Package.Name} before an install."
        opkg\Destroy!
      .Package.Parent = pkgloc
      if .Install then .Install .Package
      if .Package\IsA "Script"
        -- Sort out other package metadata for Scripts
        pak = .Package
        if .LoadOrder
          lo = .LoadOrder
          with Instance.new "IntValue"
            .Name = "LoadOrder"
            .Value = lo
            .Parent = pak
      sav = {
        Resource: .Package
        Origin:
          Name: .Name or .Package.Name
          Type: .Type
          Version: .Version
      }
      Packages[#Packages+1] = sav
      Flush!
      return sav
  UpdatePackage: Hybrid (Package, Version) ->
    apkg = Package
    -- Resolve the package
    Package, err = ResolvePackage Package
    return error "[Error][Freya Hearth] Unable to update package: \"#{err}\"", 2 unless Package
    with Package
      assert .Type,
        "[Error][Freya Hearth] Package file does not include a valid type for the package.",
        2
      unless .Package
        assert .Name,
          "[Error][Freya Hearth] Package has no name or package origin.",
          2
        .Package = apkg\FindFirstChild Name
        assert .Package,
          "[Error][Freya Hearth] Package origin is invalid.",
          2
      pkgloc = Locate .Type
      opkg = pkgloc\FindFirstChild .Package.Name
      assert opkg,
        "[Error][Freya Hearth] Nothing to update from - Package was not already present",
        2
      if .Depends
        for dep in *.Depends
          -- Origin
          -- Name
          -- Version
          return error "[Error][Freya Hearth] Malformed dependency list" unless 
          pak = GetPackage dep.Name
          if pak -- If it's installed
            if dep.Version
              -- Check that the version is alright
              clear = CompareVersions dep.Version, pak.Version
              unless clear -- Failed dep version
                warn "[Warn][Freya Hearth] Incomplete dependency #{dep.Name} #{dep.Version}. Attempting to install."
                s, err = pcall InstallPackage dep.Origin or dep.Name, dep.Version
                return error "[Error][Freya Hearth] Failed to install dependency #{dep.Name} #{dep.Version} because \"#{err}\"", 2 unless s
                print "[Info][Freya Hearth] Installed dependency #{dep.Name} #{dep.Version}"
            else
              warn "[Warn][Freya Hearth] dependency #{dep.Name} has no version specified. Be warned that it may not function."
              -- No need to install anything else.
          else
            -- Try to install the package.
            warn "[Warn][Freya Hearth] Missing dependency #{dep.Name} #{dep.Version or 'latest'}. Attempting to install."
            s, err = pcall InstallPackage dep.Origin or dep.Name, dep.Version
            return error "[Error][Freya Hearth] Failed to install dependency #{dep.Name} #{dep.Version} because \"#{err}\"", 2 unless s
            print "[Info][Freya Hearth] Installed dependency #{dep.Name} #{dep.Version or 'latest'}"
      if .Update then .Update opkg, .Package
      opkg\Destroy!
      .Package.Parent = pkgloc
      if .Package\IsA "Script"
      -- Sort out other package metadata for Scripts
        pak = .Package
        if .LoadOrder
          lo = .LoadOrder
          with Instance.new "IntValue"
            .Name = "LoadOrder"
            .Value = lo
            .Parent = pak
      sav = {
        Resource: .Package
        Origin:
          Name: .Name or .Package.Name
          Type: .Type
          Version: .Version
      }
      for pak in *Packages
        if pak.Origin.Name == sav.Origin.Name
        pak.Resource = sav.Resource
        sav = pak
        break
      Flush!
      return sav
  UninstallPackage: Hybrid (Package) ->
    apkg = Package
    -- Resolve the package
    Package, err = ResolvePackage Package
    return error "[Error][Freya Hearth] Unable to install package: #{err}", 2 unless Package
    with Package
      assert .Type,
        "[Error][Freya Hearth] Package file does not include a valid type for the package.",
        2
      unless .Name
        assert .Package,
          "[Error][Freya Hearth] Package has no name or package origin.",
          2
        .Name = .Package.Name
        assert .Name ~= '',
          "[Error][Freya Hearth] Package origin is invalid.",
          2
      ipkgloc = Locate .Type
      ipkg = ipkgloc\FindFirstChild .Name
      assert ipkg,
        "[Error][Freya Hearth] Package could not be located",
        2
      if .Uninstall then .Uninstall ipkg
      ipkg\Destroy!
      dest = false
      for i=1, #Packages
        v = Packages[i]
        if dest
          Packages[i-1] = v
          Packages[i] = nil
        elseif v.Origin.Name == (.Name or .Package.Name)
          dest = true
          Packages[i] = nil
      Flush!
  Locate: Hybrid Locate
  Flush: Hybrid Flush
  GetPackage: Hybrid (PackageName) ->
    for Package in *Packages
      return Package if Package.Origin.Name == PackageName
  :ResolveVersion
  :Packages
  :ResolvePackage
}

{:InstallPackage, :UninstallPackage, :UpdatePackage, :GetPackage} = Hearth

with getmetatable ni
  .__index = Hearth
  .__metatable = "Locked metatable: Freya Hearth"
  .__tostring = => "Freya Hearth"

return ni
