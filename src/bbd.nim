import strutils
import strformat
import httpclient
import json
import mimetypes
import osproc
import regex
import threadpool
import os
import sequtils
import sugar
import terminal
import parsetoml
import base64
import untar
from os import sleep

type
  GithubError* = object of IOError

proc newAuthorizedHttpClient(token = ""): HttpClient =
  var client = newHttpClient()
  let t = if token == "": getEnv("GITHUB_TOKEN", "") else: token
  if t != "":
    client.headers = newHttpHeaders({ "Authorization": &"token {t}" })
  return client

proc get_number_of_pages(): tuple[f:int, l:int] =
  var client = newAuthorizedHttpClient()
  let url = "https://api.github.com/orgs/JuliaBinaryWrappers/repos"
  let response = client.request(url, httpMethod = "get", body = "", headers = nil)
  let h = response.headers["link"].split(",")[1].split(";")[0]
  var m: RegexMatch
  assert h.find(re"page=(\d+)>", m)
  let last_page = parseInt(h[m.group(0)[0]])
  let first_page = 1
  return (first_page, last_page)

proc get_repos_on_page(page_number: int): seq[string] =
  var client = newAuthorizedHttpClient()
  let url = &"https://api.github.com/orgs/JuliaBinaryWrappers/repos?page={page_number}"
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

template with_progress_bar(threads: untyped, message: string, body: untyped) =
  stdout.showLine(message)

  body

  var content = ' '.repeat(threads.len)
  while not all(threads, r => r.isReady):
    # TODO: always fit in one line
    let total_threads = len(threads)
    let ready_threads = len(filter(threads, r => r.isReady))
    for progress in 0 ..< ready_threads:
      content[progress] = '#'
    stdout.showLine(message & " : " & $ready_threads & "/" & $total_threads & " [" & content & "]")
    sleep(100)

proc list(): seq[string] =
  ## Get package list.
  stdout.hideCursor()
  stdout.showLine "Fetching package sources"

  let thread = spawn get_number_of_pages()

  var counter = 0
  while not thread.isReady:
    sleep(250)
    counter += 1
    stdout.showLine("Fetching package sources: " & ".".repeat(counter mod 4))

  let (first_page, last_page) = ^thread

  var threads = newSeq[FlowVar[seq[string]]]()

  with_progress_bar(threads, "Downloading package list"):
    for page_number in first_page .. last_page:
      let r = spawn get_repos_on_page(page_number)
      threads.add(r)

  stdout.eraseLine()

  var repos = newSeq[string]()
  for r in threads:
    for repo in ^r:
      repos.add(repo)

  for repo in repos:
    echo repo

  stdout.showCursor()

  return repos

proc get_artifacts_toml(package: string): JsonNode =
  var client = newAuthorizedHttpClient()
  let url = &"https://api.github.com/repos/JuliaBinaryWrappers/{package}_jll.jl/contents/Artifacts.toml"
  let response = client.request(url, httpMethod = "get", body = "", headers = nil)
  let data = parseJson(response.body)
  return data

proc get_project_toml(package: string): JsonNode =
  var client = newAuthorizedHttpClient()
  let url = &"https://api.github.com/repos/JuliaBinaryWrappers/{package}_jll.jl/contents/Project.toml"
  let response = client.request(url, httpMethod = "get", body = "", headers = nil)
  let data = parseJson(response.body)
  return data

proc downloadFile(url: string): string =
  var client = newHttpClient()
  let filename = url.split("/")
  client.downloadFile(url, filename[filename.high])
  return filename[filename.high]

proc get_release_urls(package: string, os: string, arch: string, cxxstring_abi: string, libc: string): seq[string] =

  var os = if os == "macosx": "macos" else: os

  var arch = case arch
  of "amd64": "x86_64"
  of "i386": "i686"
  of "arm64": "aarch64"
  of "arm": "armv7l"
  of "powerpc64el": "powerpc64le"
  else: arch

  var threads = newSeq[FlowVar[JsonNode]]()
  var content: JsonNode

  with_progress_bar(threads, &"Fetching meta data for {package}"):
    threads.add spawn get_artifacts_toml(package)
    threads.add spawn get_project_toml(package)

  content = ^threads[0]

  let data = parsetoml.parseString(decode(content["content"].getStr())).toJson()

  var download_list = newSeq[string]()

  for download in data[package].getElems():
    if download["arch"]["value"].getStr == arch and download["os"]["value"].getStr == os:
      if download.haskey("cxxstring_abi") and download["cxxstring_abi"]["value"].getStr != cxxstring_abi:
        continue
      if download.haskey("libc") and download["libc"]["value"].getStr != libc:
        continue
      download_list.add(download["download"][0]["url"]["value"].getStr)

  content = ^threads[1]
  let dependencies = parsetoml.parseString(decode(content["content"].getStr())).toJson()

  for k,v in dependencies["deps"]:
    if k.endsWith("_jll"):
      download_list = concat(download_list, get_release_urls(k.replace("_jll", ""), os, arch, cxxstring_abi, libc))

  return download_list

proc untar(tarball: string, install_path: string) =
  var file = newTarFile(tarball)
  file.extract(install_path)
  removeFile(tarball)

proc install(tarball: string, install_path: string): string =
  if not dirExists(install_path):
    createDir(install_path)
  untar(tarball, install_path)
  when defined(macosx) or defined(linux):
    let bin = install_path / "bin"
    if dirExists(bin):
      discard execProcess(&"chmod -R +x {bin}")
  return install_path

proc download*(package: string, os = hostOS, arch = hostCPU, cxxstring_abi = "cxx03", libc = "", install_path = ""): string =
  ## Download package.
  stdout.hideCursor()

  stdout.showLine "Fetching meta data"

  let download_list = get_release_urls(package, os, arch, cxxstring_abi, libc)

  var threads = newSeq[FlowVar[string]]()

  with_progress_bar(threads, "Downloading assets"):
    for url in download_list:
      threads.add( spawn url.downloadFile() )
  var tarballs = newSeq[string]()
  for thread in threads:
    tarballs.add(^thread)
  stdout.eraseLine()

  if install_path != "":
    for tarball in tarballs:
      stdout.showLine &"Installing {tarball} to {install_path}"
      stdout.eraseLine()
      discard install(tarball, install_path)
    echo install_path
  else:
    for tarball in tarballs:
      echo tarball

  stdout.showCursor()

when isMainModule:
  import cligen
  include cligen/mergeCfgEnv
  const nd = staticRead "../bbd.nimble"
  clCfg.version = nd.fromNimble("version")
  dispatchMulti(
    [ list, noAutoEcho=true ],
    [ download, noAutoEcho=true ],
  )
