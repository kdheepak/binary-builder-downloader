# Package

version       = "0.1.2"
author        = "Dheepak Krishnamurthy"
description   = "Binary Builder Downloader"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["bbd"]
installFiles  = @["bbd.nim"]

# Dependencies

requires "nim >= 1.2.0"
requires "cligen"
requires "regex"
requires "parsetoml"
requires "untar"
requires "nimcr"

import strutils
import os
import strformat

task archive, "Create archived assets":
  let app = "bbd"
  let assets = &"{app}_{buildOS}"
  let dir = "dist"/assets
  mkDir dir
  cpDir "bin", dir/"bin"
  cpFile "LICENSE", dir/"LICENSE"
  cpFile "README.md", dir/"README.md"
  withDir "dist":
    when buildOS == "windows":
      exec &"7z a {assets}.zip {assets}"
    else:
      exec &"chmod +x ./{assets / \"bin\" / app}"
      exec &"tar czf {assets}.tar.gz {assets}"

task changelog, "Create a changelog":
  exec("./scripts/changelog.nim")
