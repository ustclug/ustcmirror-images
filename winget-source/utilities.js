import withRetry from 'fetch-retry'
import https from 'https'
import JSZip from 'jszip'
import originalFetch from 'node-fetch'
import os from 'os'
import path from 'path'
import process from 'process'
import sqlite3 from 'sqlite3'
import winston from 'winston'
import YAML from 'yaml'
import Zlib from 'zlib'

import { existsSync } from 'fs'
import { mkdir, mkdtemp, readFile, stat, utimes, writeFile } from 'fs/promises'
import { isIP } from 'net'
import { promisify } from 'util'

import { EX_IOERR, EX_USAGE } from './sysexits.js'


/**
 * `fetch` implementation with retry support.
 *
 * 3 retries with 1000ms delay, on network errors and HTTP code >= 400.
 */
const fetch = withRetry(originalFetch, {
    retryOn: (attempt, error, response) => {
        if (attempt > 3) return false;

        if (error || response.status >= 400) {
            if (response)
                winston.warn(`retrying ${response.url} (${attempt})`);
            else
                winston.warn(`retrying (${attempt}, error: ${error})`);
            return true;
        }
    }
});

/** The remote URL of a pre-indexed WinGet source repository. */
const remote = process.env.WINGET_REPO_URL ?? 'https://cdn.winget.microsoft.com/cache';

/** The local path to serve as the root of WinGet source repository. */
const local = process.env.TO;

/** Maximum sync jobs to be executed in parallel. Defaults to 8. */
const parallelLimit = parseInt(process.env.WINGET_REPO_JOBS ?? 8);

/** Whether the debug mode is enabled. */
const debugMode = process.env.DEBUG === 'true';

/** Whether to perform a forced sync. */
const forceSync = process.env.WINGET_FORCE_SYNC === 'true';

/** Local IP address to be bound to HTTPS requests. */
const localAddress = process.env.BIND_ADDRESS;

/** Decompress a deflated stream asynchronously. */
const inflateRaw = promisify(Zlib.inflateRaw);

/**
 * Get the local sync path of a manifest.
 *
 * @param {string} uri Manifest URI.
 *
 * @returns {string} Expected local path of the manifest file.
 */
function getLocalPath(uri) {
    return path.join(local, uri);
}

/**
 * Get the remote URL of a manifest.
 *
 * @param {string} uri Manifest URI.
 *
 * @returns {URL} Remote URL to get the manifest from.
 */
function getRemoteURL(uri) {
    const remoteURL = new URL(remote);
    remoteURL.pathname = path.posix.join(remoteURL.pathname, uri);
    return remoteURL;
}

/**
 * Decompress a MSZIP-compressed buffer.
 *
 * @param {Buffer} buffer Compressed buffer using MSZIP.
 *
 * @returns {Buffer} The decompressed buffer.
 */
async function decompressMSZIP(buffer) {
    const magicHeader = Buffer.from([0, 0, 0x43, 0x4b]);
    if (!buffer.subarray(26, 30).equals(magicHeader)) {
        throw new Error('Invalid MSZIP format');
    }
    var chunkIndex = 26;
    var decompressed = Buffer.alloc(0);
    while ((chunkIndex = buffer.indexOf(magicHeader, chunkIndex)) > -1) {
        chunkIndex += magicHeader.byteLength;
        const decompressedChunk = await inflateRaw(buffer.subarray(chunkIndex), {
            dictionary: decompressed.subarray(-32768)
        });
        decompressed = Buffer.concat([decompressed, decompressedChunk]);
    }
    return decompressed;
}

/**
 * Get last modified date from HTTP response headers.
 *
 * @param {Response} response The HTTP `fetch` response to parse.
 *
 * @returns {Date | undefined} Last modified date derived from the response, if exists.
 */
function getLastModifiedDate(response) {
    const lastModified = response.headers.get('Last-Modified');
    if (lastModified) {
        return new Date(Date.parse(lastModified));
    } else {
        return undefined;
    }
}

/**
 * Get content length from HTTP response headers.
 *
 * @param {Response} response The HTTP `fetch` response to parse.
 *
 * @returns {number} Content length derived from the response, in bytes.
 */
function getContentLength(response) {
    const length = response.headers.get('Content-Length');
    if (length) {
        return parseInt(length);
    } else {
        return 0;
    }
}

/**
 * Resolve path parts against the local storage.
 *
 * @param {number} id The ID of the target path part.
 * @param {Map<number, { parent: number, pathpart: string }>} pathparts Path part storage built from the database.
 *
 * @returns {string} Full URI resolved from the given path part ID.
 */
function resolvePathpart(id, pathparts) {
    const pathpart = pathparts.get(id);
    if (pathpart === undefined) {
        return '';
    }
    return path.posix.join(resolvePathpart(pathpart.parent, pathparts), pathpart.pathpart);
}

/**
 * Resolve manifest URIs against package metadata.
 *
 * Reference: https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/PackageVersionDataManifest.cpp
 *
 * @param {{ sV: string, vD: { v: string, rP: string | undefined, s256H: string | undefined }[], [key: string]: any }} metadata The parsed package metadata object.
 *
 * @returns {string[]} URIs resolved from the given metadata.
 */
function resolvePackageManifestURIs(metadata) {
    return metadata.vD.map((version) => version.rP).filter(Boolean);
}

/**
 * Set up the default `winston` logger instance.
 */
function setupWinstonLogger() {
    const { format, transports } = winston;
    winston.configure({
        format: format.errors({ stack: debugMode }),
        transports: [
            new transports.Console({
                handleExceptions: true,
                level: debugMode ? 'debug' : 'info',
                stderrLevels: ['error'],
                format: format.combine(
                    format.timestamp(),
                    format.printf(({ timestamp, level, message, stack }) =>
                        `[${timestamp}][${level.toUpperCase()}] ${stack ?? message}`
                    )
                )
            })
        ]
    });
}

/**
 * Build a local storage for path parts from database query.
 *
 * @param {{ rowid: number, parent: number, pathpart: string }[]} rows Rows returned by the query.
 *
 * @returns {Map<number, { parent: number, pathpart: string }>} In-memory path part storage to query against.
 */
export function buildPathpartMap(rows) {
    return new Map(rows.map(row =>
        [row.rowid, { parent: row.parent, pathpart: row.pathpart }]
    ));
}

/**
 * Build a list of all manifest URIs from database query.
 *
 * @param {{ pathpart: string, [key: string]: string }[]} rows Rows returned by the query.
 * @param {Map<number, { parent: number, pathpart: string }>} pathparts Path part storage built from the database.
 *
 * @returns {string[]} Manifest URIs to sync.
 */
export function buildManifestURIs(rows, pathparts) {
    return rows.map(row => resolvePathpart(row.pathpart, pathparts));
}

/**
 * Build a list of all package metadata URIs from database query.
 *
 * @param {{ id: string, hash: Buffer, [key: string]: string }[]} rows Rows returned by the query.
 *
 * @returns {string[]} Package metadata URIs to sync.
 */
export function buildPackageMetadataURIs(rows) {
    return rows.map(row =>
        path.posix.join('packages', row.id, row.hash.toString('hex').slice(0, 8), 'versionData.mszyml')
    );
}

/**
 * Exit with given status with error logging.
 *
 * @param {number} code Exit code to use.
 * @param {Error | string | null | undefined} error Error to log.
 *
 * @returns {never} Exits the process.
 */
export function exitWithCode(code = 0, error = undefined) {
    if (error) {
        winston.exitOnError = false;
        winston.error(error);
    }
    process.exit(code);
}

/**
 * Build a list of all manifest URIs from compressed package metadata.
 *
 * Reference: https://github.com/kyz/libmspack/blob/master/libmspack/mspack/mszipd.c
 *
 * @param {fs.PathLike | Buffer} mszymlMetadata Path or buffer of the MSZYML metadata file.
 *
 * @returns {Promise<string[]>} Manifest URIs to sync.
 */
export async function buildManifestURIsFromPackageMetadata(mszymlMetadata) {
    const compressedBuffer = Buffer.isBuffer(mszymlMetadata) ? mszymlMetadata : await readFile(mszymlMetadata);
    const buffer = await decompressMSZIP(compressedBuffer);
    const metadata = YAML.parse(buffer.toString());
    return resolvePackageManifestURIs(metadata);
}

/**
 * Extract database file from the source bundle.
 *
 * @param {fs.PathLike | Buffer} msixFile Path or buffer of the MSIX bundle file.
 * @param {fs.PathLike} directory Path of directory to save the file.
 *
 * @returns {Promise<string>} Path of the extracted `index.db` file.
 */
export async function extractDatabaseFromBundle(msixFile, directory) {
    const bundle = Buffer.isBuffer(msixFile) ? msixFile : await readFile(msixFile);
    const zip = await JSZip.loadAsync(bundle);
    const buffer = await zip.file(path.posix.join('Public', 'index.db')).async('Uint8Array');
    const destination = path.join(directory, 'index.db');
    await writeFile(destination, buffer);
    return destination;
}

/**
 * Create a unique temporary directory with given prefix.
 *
 * @param {string} prefix Temporary directory name prefix. Must not contain path separators.
 *
 * @returns {Promise<string>} Path to the created temporary directory.
 */
export async function makeTempDirectory(prefix) {
    try {
        return await mkdtemp(path.join(os.tmpdir(), prefix));
    } catch (error) {
        exitWithCode(EX_IOERR, error);
    }
}

/**
 * Check and set up the environment.
 *
 * @returns Values and objects to be used in the program.
 */
export function setupEnvironment() {
    setupWinstonLogger();
    if (!local) {
        exitWithCode(EX_USAGE, "destination path $TO not set!");
    }
    if (localAddress) {
        https.globalAgent.options.localAddress = localAddress;
        https.globalAgent.options.family = isIP(localAddress);
    }
    return {
        debugMode,
        forceSync,
        local,
        parallelLimit,
        remote,
        sqlite3: debugMode ? sqlite3.verbose() : sqlite3,
        winston
    };
}

/**
 * Cache a file with specific modified date.
 *
 * @param {string} uri File URI to cache.
 * @param {Buffer} buffer Whether to save the file to disk.
 * @param {Date | null | undefined} modifiedAt Modified date of the file, if applicable.
 *
 * @returns {Promise<void>} Fulfills with `undefined` upon success.
 */
export async function cacheFileWithURI(uri, buffer, modifiedAt) {
    const path = getLocalPath(uri);
    await writeFile(path, buffer);
    if (modifiedAt) {
        await utimes(path, modifiedAt, modifiedAt);
    }
}

/**
 * Sync a file with the remote server asynchronously.
 *
 * @param {string} uri URI to sync.
 * @param {boolean} update Whether to allow updating an existing file.
 * @param {boolean} save Whether to save the file to disk.
 *
 * @returns {Promise<[?Buffer, ?Date, boolean]>} File buffer, last modified date and if the file is updated.
 */
export async function syncFile(uri, update = true, save = true) {
    const localPath = getLocalPath(uri);
    const remoteURL = getRemoteURL(uri);
    await mkdir(path.dirname(localPath), { recursive: true });
    if (existsSync(localPath)) {
        if (!update) {
            winston.debug(`skipped ${uri} because it already exists`);
            return [null, null, false];
        }
        const response = await fetch(remoteURL, { method: 'HEAD' });
        const lastModified = getLastModifiedDate(response);
        const contentLength = getContentLength(response);
        if (lastModified) {
            const localFile = await stat(localPath);
            if (localFile.mtime.getTime() == lastModified.getTime() && localFile.size == contentLength) {
                winston.debug(`skipped ${uri} because it's up to date`);
                return [await readFile(localPath), lastModified, false];
            }
        }
    }
    winston.info(`downloading from ${remoteURL}`);
    const response = await fetch(remoteURL);
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    const lastModified = getLastModifiedDate(response);
    if (save) {
        await cacheFileWithURI(uri, buffer, lastModified);
    }
    return [buffer, lastModified ?? null, true];
}
