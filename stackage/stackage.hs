
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE OverloadedStrings #-}
import Data.Yaml
import Data.Aeson.Types     (ToJSON)
import Data.Maybe           (isNothing, fromJust)
import qualified Data.Map.Strict as M
import System.IO                (readFile, writeFile)
import System.Exit              (ExitCode(..))
import System.Process           (callProcess, readProcessWithExitCode)
import System.Directory
import System.Environment       (getEnv)
import System.FilePath.Posix    (FilePath, (</>))
import Control.Exception        (catch)
import Control.Monad            (when, unless)
import Data.List.Split          (splitOn)
import Text.Printf              (printf)


type URL = String
type SHA1 = String

type Platform = String
type Version = String

--
--  following data defs and instances
--  are for stack-setup-2.yaml parsing
--

data ResourceInfo = ResourceInfo {
    version         :: String,
    url             :: String,
    contentLength   :: Int,
    sha1            :: String,
    configureEnv    :: M.Map String String
} deriving (Show)


data StackSetup = StackSetup {
    sevenzexeInfo   :: ResourceInfo,
    sevenzdllInfo   :: ResourceInfo,
    msys2           :: M.Map Platform ResourceInfo,
    ghc             :: M.Map Platform (M.Map Version ResourceInfo)
} deriving (Show)

instance FromJSON ResourceInfo where
    parseJSON = withObject "ResourceInfo" $ \o -> do
        version <- o .:? "version" .!= ""
        url <- o .: "url"
        contentLength <- o .: "content-length"
        sha1 <- o .: "sha1"
        configureEnv <- o .:? "configure-env" .!= M.fromList []
        return ResourceInfo {..}

instance ToJSON ResourceInfo where
    toJSON (ResourceInfo v u c s e) = object $
            (if null v then [] else ["version" .= v]) ++
            ["url" .= u, "content-length" .= c, "sha1" .= s] ++
            (if M.null e then [] else ["configure-env" .= e])

instance FromJSON StackSetup where
    parseJSON = withObject "StackSetup" $ \o -> do
        sevenzexeInfo <- o .: "sevenzexe-info"
        sevenzdllInfo <- o .: "sevenzdll-info"
        msys2 <- o .: "msys2"
        ghc <- o .: "ghc"
        return StackSetup {..}

instance ToJSON StackSetup where
    toJSON (StackSetup e d m g) = object
            ["sevenzexe-info" .= e,
             "sevenzdll-info" .= d,
             "msys2"          .= m,
             "ghc"            .= g]




-- download a file to given path
-- sha-1 checksum is enabled when sha isn't empty string
download :: URL -> FilePath -> SHA1 -> Bool -> IO ()
download url path sha force = do
    let fileName = last (splitOn "/" url)
    let filePath = path </> fileName
    putStrLn $ printf "Try to Download %s..." fileName
    pathExists <- doesDirectoryExist path
    unless pathExists (createDirectory path)
    filePathExists <- doesFileExist filePath
    if filePathExists && not force
       then putStrLn $ printf "%s already exists. Just skip." filePath
       else do
           let args_ = [url, "--dir=" ++ path,
                          "--out=" ++ fileName ++ ".tmp",
                          "--file-allocation=none", "--quiet=true"]

           -- if sha isn't an empty string, append checksum option
           let args = args_ ++ (words sha >>= \s -> ["--checksum=sha-1=" ++ s])

           (exitCode, _, _) <- readProcessWithExitCode "aria2c" args ""
           if exitCode == ExitSuccess
           then callProcess "mv" [filePath ++ ".tmp", filePath] >>
                putStrLn  (printf "Downloaded %s to %s." fileName filePath)
           else putStrLn $ printf "Download failure on %s" fileName

updateChannels :: FilePath -> IO ()
updateChannels  basePath =
    mapM_ loadChannel ["lts-haskell", "stackage-nightly"]
        where loadChannel channel = do
                  let destPath = basePath </> channel
                  exists <- doesDirectoryExist destPath
                  if exists
                     then do putStrLn $ printf "Start to pull latest %s channel" channel
                             callProcess "git" ["-C", destPath, "pull"]
                             putStrLn $ printf "Pull %s finish" channel
                     else do putStrLn $ printf "%s channel doesn't exist, start first clone" channel
                             callProcess "git" ["clone", "--depth", "1",
                                            "https://github.com/fpco/" ++ channel ++ ".git",
                                            destPath]
                             putStrLn $ printf "Clone %s finish" channel

stackSetup :: FilePath -> FilePath -> IO ()
stackSetup bp setupPath = do
    jr <- catch (decodeFile setupPath) 
                (\e -> do putStrLn (prettyPrintParseException e)
                          return Nothing) :: IO (Maybe StackSetup)

    when (isNothing jr) (error "Parse setup yaml failure")

    let r = fromJust jr

    let (StackSetup e d m g) = r

    let filesToDownload = M.toList g >>= M.toList . snd >>= return . snd

    let dlEachGhc (ResourceInfo _ u _ s _) = download u (bp </> "ghc") s False
        in sequence_ $ map dlEachGhc filesToDownload


    let msys2 = M.fromList [
                        ("windows32", ResourceInfo "20161025" "https://mirrors.ustc.edu.cn/msys2/distrib/i686/msys2-base-i686-20161025.tar.xz" 47526500 "5d17fa53077a93a38a9ac0acb8a03bf6c2fc32ad" (M.fromList [])),
                        ("windows64", ResourceInfo "20161025" "https://mirrors.ustc.edu.cn/msys2/distrib/x86_64/msys2-base-x86_64-20161025.tar.xz" 47166584 "05fd74a6c61923837dffe22601c9014f422b5460" (M.fromList []))
                    ]


    let newGhc = M.map (M.map riF) g
            where riF (ResourceInfo v u c s e) = (ResourceInfo v (redirect u) c s e)
                  redirect = ("https://mirrors.ustc.edu.cn/stackage/ghc/" ++) .
                            last . splitOn "/"

    encodeFile (bp </> "stack-setup.yaml") (StackSetup e d msys2 newGhc)
    putStrLn $ printf "Stack setup successfully processed"


main :: IO ()
main = do
    -- specify what place to save the mirror TO
    basePath <- getEnv "TO"

    -- update channel
    updateChannels basePath

    -- load snapshots
    download "https://www.stackage.org/download/snapshots.json" basePath "" True

    -- load stack setup
    download "https://raw.githubusercontent.com/fpco/stackage-content/master/stack/stack-setup-2.yaml"
             "/tmp"
             ""
             True

    stackSetup basePath "/tmp/stack-setup-2.yaml"

    putStrLn "sync finish"
