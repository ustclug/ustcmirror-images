module Main where

import           Control.Applicative
import           Control.Concurrent
import           Control.Concurrent.STM.TSem
import           Control.Exception
import           Control.Lens
import           Control.Monad
import           Control.Monad.STM
import qualified Data.Aeson as Aeson
import           Data.Aeson.Lens
import           Data.Foldable
import           Data.List
import           Data.List.Split
import           Data.Maybe
import           Data.Set (Set)
import qualified Data.Set as Set
import           Data.Text (Text)
import qualified Data.Text as Text
import           Data.Version
import qualified Data.Yaml.Aeson as Yaml
import           GHC.Exts
import           Network.URI
import           System.Directory
import           System.Environment
import           System.FilePath
import           System.Posix.Directory
import           System.Process.Typed
import           Text.ParserCombinators.ReadP
import           Text.Printf
import           Text.Read

type URL = Text
type SHA256 = Text

main :: IO ()
main = do
  basedir <- getEnv "TO"

  -- Set up metadata in a working directory
  gitClone ghcupMetadataRepo (mdtmpdir basedir)

  -- Download all artifacts referenced in _supported_ metadata files
  files <- listDirectory (mdtmpdir basedir)
  let isSupported filename =
        case parseVersionFromFileName filename of
          Just version -> version >= minimumSupportedVersion
          Nothing      -> False
      mdfiles = filter isSupported . filter ("yaml" `isExtensionOf`) $ files
      mdpaths = map (mdtmpdir basedir </>) mdfiles
  for_ mdpaths $ \mdpath ->
    printf "Will sync: %s\n" mdpath
  mapM_ (syncByMetadata basedir) mdpaths

  -- Delete unreferenced files (before replacing URLs)
  garbageCollect basedir mdpaths

  -- Replace URLs in tmp metadata, and then copy these files
  mapM_ replaceUrls mdpaths
  enableMetadata basedir

ghcupMetadataRepo :: URL
ghcupMetadataRepo = "https://github.com/haskell/ghcup-metadata"

mirroredFileUrl :: IsString str => FilePath -> str
mirroredFileUrl local = fromString $ printf "http://mirrors.ustc.edu.cn/ghcup/%s" local

minimumSupportedVersion :: Version
minimumSupportedVersion = makeVersion [0, 0, 6]  -- Metadata format version

parseVersionFromFileName :: FilePath -> Maybe Version
parseVersionFromFileName filename = do
  let basename = takeBaseName filename
  noPrefix <- stripPrefix "ghcup-prereleases-" basename
          <|> stripPrefix "ghcup-" basename
  listToMaybe $ map fst . filter (\(_, rem) -> null rem) $ readP_to_S parseVersion noPrefix

------------------------------------------------------------------------
syncByMetadata :: FilePath -> FilePath -> IO ()
syncByMetadata basedir mdpath = do
  md <- readMetadata mdpath
  let urls = md ^.. deep (key "dlUri" . _String)
      sha256s = md ^.. deep (key "dlHash" . _String)
      dlUris = Set.toList . Set.fromList $ zip urls sha256s
      nthreads = 4
  printf "Sync'ing metadata %s... \n" mdpath
  mapM_ (downloadConcurrently basedir) (chunksOf nthreads dlUris)

downloadConcurrently :: FilePath -> [(URL, SHA256)] -> IO ()
downloadConcurrently basedir urls = do
  barrier <- atomically $ newTSem (1 - fromIntegral (length urls))
  for_ urls $ \url -> forkIO $ do
    download basedir url
    atomically $ signalTSem barrier
  atomically $ waitTSem barrier

download :: FilePath -> (URL, SHA256) -> IO ()
download basedir (url, sha256) = do
  let path = basedir </> urlExtractPath url
  exists <- doesFileExist path
  if exists
    then do printf "%s already exists. Skipped.\n" path
    else do printf "Downloading %s to %s ...\n" url path
            downloadFile url sha256 path

  where
    downloadFile :: URL -> SHA256 -> FilePath -> IO ()
    downloadFile url sha256 path = do
      let dir = takeDirectory path
          filename = takeFileName path
          args = [Text.unpack url,
                  "--dir=" ++ dir,
                  "--out=" ++ filename ++ ".tmp",
                  "--file-allocation=none",
                  "--quiet=true",
                  "--checksum=sha-256=" ++ Text.unpack sha256]
      createDirectoryIfMissing True dir
      exitCode <- runProcess (proc "aria2c" args)
      case exitCode of
        ExitSuccess -> do
          -- Atomically make the file visible.
          renameFile (dir </> filename ++ ".tmp") (dir </> filename)
        ExitFailure code -> do
          -- Probably due to Not Found errors.  Just ignore the error
          -- so that the signalTSem can be reached, or there will be a
          -- deadlock.
          printf "! Couldn't download %s (exit code = %d)" url code
          removePathForcibly (dir </> filename ++ ".tmp")

readMetadata :: FilePath -> IO Aeson.Value
readMetadata path = either throwIO pure =<< Yaml.decodeFileEither path

urlExtractPath :: Text -> FilePath
urlExtractPath url = fromJust $ do
  uri <- parseURI (Text.unpack url)
  authority <- uriAuthority uri
  pure (uriRegName authority <> uriPath uri)

------------------------------------------------------------------------
mddir :: FilePath -> FilePath
mddir base = base </> "ghcup-metadata"

mdtmpdir :: FilePath -> FilePath
mdtmpdir base = base </> "ghcup-metadata.tmp"

gitClone :: URL -> FilePath -> IO ()
gitClone url path = do
  removePathForcibly path
  runProcess_ (proc "git" ["clone", "--depth=1", Text.unpack url, path])

------------------------------------------------------------------------
replaceUrls :: FilePath -> IO ()
replaceUrls mdpath = do
  md <- readMetadata mdpath
  let md' = md & deep (key "dlUri" . _String) %~ localizeUrl
  Yaml.encodeFile mdpath md'
  where
    localizeUrl :: Text -> Text
    localizeUrl url = mirroredFileUrl (urlExtractPath url)

enableMetadata :: FilePath -> IO ()
enableMetadata basedir = do
  removePathForcibly (mddir basedir)
  removePathForcibly (mdtmpdir basedir </> ".git")
  renamePath (mdtmpdir basedir) (mddir basedir)

------------------------------------------------------------------------
garbageCollect :: FilePath -> [FilePath] -> IO ()
garbageCollect basedir mdpaths = do
  printf "Garbage collecting...\n"

  -- Get all referenced paths
  let f path = do
        md <- readMetadata path
        return . Set.fromList . map urlExtractPath $ (md ^.. deep (key "dlUri" . _String))
  keep <- foldMap f mdpaths

  -- List all local files and remove unused files
  let keepAnyway = ["ghcup-metadata.tmp", "ghcup-metadata", "sh"]
  files <- listDirectoryRecursive basedir
  for_ files $ \file ->
    unless (file `Set.member` keep || any (`isPrefixOf` file) keepAnyway) $ do
      printf "Delete unreferenced file %s\n" file
      removeFile (basedir </> file)

  where
    listDirectoryRecursive :: FilePath -> IO [FilePath]
    listDirectoryRecursive = go ""
      where
        go prefix curpath = do
          files <- listDirectory curpath
          let f file = do
                d <- doesDirectoryExist (curpath </> file)
                if d
                  then go (prefix </> file) (curpath </> file)
                  else pure [prefix </> file]
          foldMap f files
