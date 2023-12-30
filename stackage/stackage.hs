{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

import Control.Monad (unless)
import Data.Aeson qualified as A
import Data.ByteString.Lazy qualified as BS
import Data.List.Split (splitOn)
import Data.Map.Strict qualified as M
import Data.Yaml
import System.Directory (createDirectory, doesDirectoryExist, doesFileExist)
import System.Environment (getEnv)
import System.Exit (ExitCode (..))
import System.FilePath.Posix ((</>))
import System.Process (callProcess, readProcessWithExitCode)
import Text.Printf (printf)

type URL = String

type SHA1 = String

type SHA256 = String

type Platform = String

type Version = String

type Path = String

--
--  following data defs and instances
--  are for stack-setup-2.yaml parsing
--

data ResourceInfo = ResourceInfo
  { version :: String,
    url :: String,
    contentLength :: Int,
    sha1 :: SHA1,
    sha256 :: SHA256
  }
  deriving (Show)

newtype GhcJSInfo = GhcJSInfo
  { source :: M.Map String ResourceInfo
  }
  deriving (Show)

data StackSetup = StackSetup
  { stack :: M.Map Platform (M.Map Version ResourceInfo),
    sevenzexeInfo :: ResourceInfo,
    sevenzdllInfo :: ResourceInfo,
    portableGit :: ResourceInfo,
    msys2 :: M.Map Platform ResourceInfo,
    ghc :: M.Map Platform (M.Map Version ResourceInfo),
    ghcjs :: GhcJSInfo
  }
  deriving (Show)

data GitHubReleases = GitHubReleases
  { prerelease :: Bool,
    urls :: [URL]
  }
  deriving (Show)

instance FromJSON GhcJSInfo where
  parseJSON = withObject "GhcJSInfo" $ \o -> do
    source <- o .: "source"
    return GhcJSInfo {..}

instance ToJSON GhcJSInfo where
  toJSON (GhcJSInfo source) =
    object
      ["source" .= source]

instance FromJSON ResourceInfo where
  parseJSON = withObject "ResourceInfo" $ \o -> do
    version <- o .:? "version" .!= ""
    url <- o .: "url"
    contentLength <- o .:? "content-length" .!= (-1)
    sha1 <- o .:? "sha1" .!= ""
    sha256 <- o .:? "sha256" .!= ""
    return ResourceInfo {..}

instance ToJSON ResourceInfo where
  toJSON (ResourceInfo v u c s1 s256) =
    object $
      (["version" .= v | not (null v)])
        ++ ["url" .= u]
        ++ (["content-length" .= c | c /= (-1)])
        ++ (["sha1" .= s1 | not (null s1)])
        ++ (["sha256" .= s256 | not (null s256)])

instance FromJSON StackSetup where
  parseJSON = withObject "StackSetup" $ \o -> do
    stack <- o .: "stack"
    sevenzexeInfo <- o .: "sevenzexe-info"
    sevenzdllInfo <- o .: "sevenzdll-info"
    portableGit <- o .: "portable-git"
    msys2 <- o .: "msys2"
    ghc <- o .: "ghc"
    ghcjs <- o .: "ghcjs"
    return StackSetup {..}

instance ToJSON StackSetup where
  toJSON (StackSetup stack exe dll pgit msys2 ghc ghcjs) =
    object
      [ "stack" .= stack,
        "sevenzexe-info" .= exe,
        "sevenzdll-info" .= dll,
        "portable-git" .= pgit,
        "msys2" .= msys2,
        "ghc" .= ghc,
        "ghcjs" .= ghcjs
      ]

instance FromJSON GitHubReleases where
  parseJSON = withObject "GitHubReleases" $ \o -> do
    prerelease <- o .: "prerelease"
    urls <- o .: "assets" >>= mapM (.: "browser_download_url")
    return GitHubReleases {..}

redirectToMirror :: Path -> ResourceInfo -> ResourceInfo
redirectToMirror relPath (ResourceInfo ver url conLen s1 s256) =
  let redirect = (++) ("https://mirrors.ustc.edu.cn/stackage/" ++ relPath ++ "/") . head . splitOn "?" . last . splitOn "/"
   in ResourceInfo ver (redirect url) conLen s1 s256

-- download a file to given path
-- sha-1 checksum is enabled when sha isn't empty string
download :: URL -> FilePath -> (SHA1, SHA256) -> Bool -> IO ()
download url path sha force = do
  let fileName = head (splitOn "?" (last (splitOn "/" url)))
  let filePath = path </> fileName
  putStrLn $ printf "Try to Download %s..." fileName
  pathExists <- doesDirectoryExist path
  unless pathExists (createDirectory path)
  filePathExists <- doesFileExist filePath
  if filePathExists && not force
    then putStrLn $ printf "%s already exists. Just skip." filePath
    else do
      let args_ =
            [ url,
              "--dir=" ++ path,
              "--out=" ++ fileName ++ ".tmp",
              "--file-allocation=none",
              "--quiet=true"
            ]

      -- if sha1 isn't an empty string, append checksum option
      let sha1Arg = words (fst sha) >>= \s -> ["--checksum=sha-1=" ++ s]
      let sha256Arg = words (snd sha) >>= \s -> ["--checksum=sha-256=" ++ s]
      let args = args_ ++ (if null sha256Arg then sha1Arg else sha256Arg)

      (exitCode, _, _) <- readProcessWithExitCode "aria2c" args ""
      if exitCode == ExitSuccess
        then
          callProcess "mv" [filePath ++ ".tmp", filePath]
            >> putStrLn (printf "Downloaded %s to %s." fileName filePath)
        else putStrLn $ printf "Download failure on %s" fileName

updateChannels :: FilePath -> IO ()
updateChannels basePath =
  mapM_ loadChannel ["lts-haskell", "stackage-nightly", "stackage-snapshots", "stackage-content"]
  where
    loadChannel channel = do
      let destPath = basePath </> channel
      exists <- doesDirectoryExist destPath
      if exists
        then do
          putStrLn $ printf "Start to pull latest %s channel" channel
          callProcess "git" ["-C", destPath, "pull"]
          putStrLn $ printf "Pull %s finish" channel
        else do
          putStrLn $ printf "%s channel doesn't exist, start first clone" channel
          callProcess
            "git"
            [ "clone",
              "--depth",
              "1",
              "https://github.com/commercialhaskell/" ++ channel ++ ".git",
              destPath
            ]
          putStrLn $ printf "Clone %s finish" channel

stackSetup :: FilePath -> FilePath -> IO ()
stackSetup bp setupPath = do
  jr <- decodeFileEither setupPath :: IO (Either ParseException StackSetup)
  r <- case jr of
    Left err -> do
      putStrLn (prettyPrintParseException err)
      error "Parse setup yaml failure"
    Right obj -> return obj

  let (StackSetup stack exe dll pgit msys2 ghc ghcjs) = r

  --  store stack
  --  let filesToDownload = M.toList stack >>= M.toList . snd >>= return . snd

  --  let dlEachStack (ResourceInfo _ u _ s1 s256) = download u (bp </> "stack") (s1, s256) False
  --      in mapM_ dlEachStack filesToDownload

  let newStack = M.map (M.map (redirectToMirror "stack")) stack

  -- store 7z
  let dl7z (ResourceInfo _ u _ s1 s256) = download u (bp </> "7z") (s1, s256) False
   in do
        dl7z exe
        dl7z dll

  let newExe = redirectToMirror "7z" exe
  let newDll = redirectToMirror "7z" dll

  -- store portable git
  let dlGit (ResourceInfo _ u _ s1 s256) = download u (bp </> "pgit") (s1, s256) False
   in dlGit pgit

  let newPgit = redirectToMirror "pgit" pgit

  -- store ghc
  let filesToDownload = map snd $ M.elems ghc >>= M.toList

  let dlGhc (ResourceInfo _ u _ s1 s256) = download u (bp </> "ghc") (s1, s256) False
   in mapM_ dlGhc filesToDownload

  let newGhc = M.map (M.map (redirectToMirror "ghc")) ghc

  -- store msys2
  let filesToDownload = snd <$> M.toList msys2

  let dlMsys2 (ResourceInfo _ u _ s1 s256) = download u (bp </> "msys2") (s1, s256) False
   in mapM_ dlMsys2 filesToDownload

  let newMsys2 = M.map (redirectToMirror "msys2") msys2

  encodeFile (bp </> "stack-setup.yaml") (StackSetup newStack newExe newDll newPgit newMsys2 newGhc ghcjs)
  putStrLn $ printf "Stack setup successfully processed"

syncStack :: FilePath -> IO ()
syncStack basePath = do
  putStrLn "start to sync stack"
  download
    "https://api.github.com/repos/commercialhaskell/stack/releases/latest"
    "/tmp"
    ("", "")
    True
  let filename = "/tmp/latest"
  text <- BS.readFile filename
  let latestInfo = case A.decode text of
        Just o -> o :: GitHubReleases
        _ -> error "decode latest fail!"
  let isPreRelease = prerelease latestInfo
  let assetsURLs = urls latestInfo
  unless isPreRelease (syncAssets assetsURLs)
  where
    syncAssets = mapM_ syncAsset
    syncAsset urlValue = do
      download
        urlValue
        (basePath </> "stack")
        ("", "")
        False

main :: IO ()
main = do
  -- specify what place to save the mirror TO
  basePath <- getEnv "TO"

  -- update channel
  updateChannels basePath

  -- load snapshots
  download "https://www.stackage.org/download/snapshots.json" basePath ("", "") True

  -- load stack setup
  download
    "https://raw.githubusercontent.com/fpco/stackage-content/master/stack/stack-setup-2.yaml"
    "/tmp"
    ("", "")
    True

  stackSetup basePath "/tmp/stack-setup-2.yaml"

  -- sync stack from github
  syncStack basePath

  putStrLn "sync finish"
