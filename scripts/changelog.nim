#!/usr/bin/env nimcr
#nimcr-args c --verbosity:0

import osproc
import strutils
import strformat
import sequtils
import algorithm

discard execProcess("git fetch --all --tags")

var newesttag = strip(execProcess("git tag -l --points-at HEAD"))

let tags = sorted(splitLines(strip(execProcess "git tag -l \"*\"")), order = SortOrder.Descending)

for tag in tags:

  if newesttag == "":
    newesttag = tag
    continue
  if tag == newesttag:
    continue

  var log = execProcess &"git log --pretty=short --oneline {tag}..{newesttag}"

  var lines : seq[string] = @[]
  for line in splitLines(log, keep_eol = true):
      lines.add(line.strip())
      lines.add("\n")

  var httpUrl = execProcess("git config --get remote.origin.url").strip()

  if "git@" in httpUrl:
    httpUrl = httpUrl.replace(":", "/")
    httpUrl = httpUrl.replace("git@", "https://")

  if httpUrl[^4..^1] == ".git":
      httpUrl = httpUrl[0..^5]

  log = join(lines).strip()

  lines = @[]
  for line in splitLines(log, keep_eol = true):
      var data = line.split()
      let commithash = fmt"[`{data[0]}`]({httpUrl}/commit/{data[0]})"
      let message = join(data[1..^1], " ")
      lines.add(commithash)
      lines.add(" ")
      lines.add(message)
      lines.add("\n")
  log = join(lines).strip()

  echo log
  break
