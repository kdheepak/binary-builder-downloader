# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import strutils
import strformat
import httpclient
import json
import mimetypes
import ospaths
import osproc
import regex
import threadpool
import os
import sequtils
import sugar
import terminal

type
  GithubError* = object of IOError

proc get_number_of_pages(token: string): tuple[f:int, l:int] =
  var client = newHttpClient()
  let t = if token == "": getEnv("GITHUB_TOKEN", "") else: token
  if t != "":
    client.headers = newHttpHeaders({ "Authorization": fmt"token {t}" })

  let url = "https://api.github.com/orgs/JuliaBinaryWrappers/repos"
  let response = client.request(url, httpMethod = "get", body = "", headers = nil)
  let h = response.headers["link"].split(",")[1].split(";")[0]
  var m: RegexMatch
  assert h.find(re"page=(\d+)>", m)
  let last_page = parseInt(h[m.group(0)[0]])
  let first_page = 1
  return (first_page, last_page)

proc get_repos_on_page(token: string, page_number: int): seq[string] {.thread.} =
  var client = newHttpClient()
  let t = if token == "": getEnv("GITHUB_TOKEN", "") else: token
  if t != "":
    client.headers = newHttpHeaders({ "Authorization": fmt"token {t}" })
  let url = fmt"https://api.github.com/orgs/JuliaBinaryWrappers/repos?page={page_number}"
  let response = client.request(url, httpMethod = "get", body = "", headers = nil)
  let data = parseJson(response.body)
  var repos: seq[string] = @[]
  for repo in data:
    repos.add(repo["full_name"].getStr().replace("JuliaBinaryWrappers/", "").replace("_jll.jl", ""))
  return repos

proc showLine(f: File, s: string) =
  f.eraseLine()
  f.write(s)
  f.flushFile()

proc list(token: string = ""): seq[string] =
  ## Get package list.
  stdout.hideCursor()
  stdout.showLine "Fetching package sources"

  let thread = spawn get_number_of_pages(token)

  var counter = 0
  while not thread.isReady:
    os.sleep(250)
    counter += 1
    stdout.showLine("Fetching package sources: " & ".".repeat(counter mod 4))

  let (first_page, last_page) = ^thread

  var content = ' '.repeat(last_page)
  stdout.showLine("Downloading package list: [$1]" % [content])

  var threads = newSeq[FlowVar[seq[string]]]()

  for page_number in first_page .. last_page:
    let r = spawn get_repos_on_page(token, page_number)
    threads.add(r)

  while not all(threads, r => r.isReady):
    # TODO: always fit in one line
    for progress in 0 ..< len(filter(threads, r => r.isReady)):
      content[progress] = '#'
    stdout.showLine("Downloading package list: [$1]" % [content])
    os.sleep(100)

  stdout.eraseLine()

  var repos = newSeq[string]()
  for r in threads:
    for repo in ^r:
      repos.add(repo)

  for repo in repos:
    echo repo

  stdout.showCursor()

  return repos

proc download(package: string = "", token: string = ""): string =
  ## Download package.
  return "/path/to/download"

when isMainModule:
  import cligen
  const nd = staticRead "../bbd.nimble"
  dispatchMulti(
    [ list, noAutoEcho=true ],
    [ download ],
  )
