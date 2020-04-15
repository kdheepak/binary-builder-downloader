# Package

version       = "0.1.0"
author        = "Dheepak Krishnamurthy"
description   = "Binary Builder Downloader"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["bbd"]

# Dependencies

requires "nim >= 1.2.0"
requires "cligen"
requires "regex"
requires "parsetoml"

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
      exec &"tar czf {assets}.tar.gz {assets}"
