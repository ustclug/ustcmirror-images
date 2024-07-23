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

/** Local IP address to be bound to HTTPS requests. */
const localAddress = process.env.BIND_ADDRESS;

/** Decompress a deflated stream asynchronously. */
const inflateRaw = promisify(Zlib.inflateRaw);

/**
 * Decompress a MSZIP-compressed buffer.
 *
 * @param {Buffer} buffer Compressed buffer using MSZIP.
 *
 * @returns {Buffer} The decompressed buffer.
 */
async function decompressMSZIP(buffer) {
    if (buffer.toString('ascii', 28, 30) != 'CK') {
        throw new Error('Invalid MSZIP format');
    }
    return await inflateRaw(buffer.subarray(30));
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
 * @param {{ sV: string, vD: { v: string, rP: string, s256H: string }[], [key: string]: any }} metadata The parsed package metadata object.
 *
 * @returns {string[]} URIs resolved from the given metadata.
 */
function resolvePackageManifestURIs(metadata) {
    return metadata.vD.map((version) => version.rP);
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
 * Get the local sync path of a manifest.
 *
 * @param {string} uri Manifest URI.
 *
 * @returns {string} Expected local path of the manifest file.
 */
export function getLocalPath(uri) {
    return path.join(local, uri);
}

/**
 * Get the remote URL of a manifest.
 *
 * @param {string} uri Manifest URI.
 *
 * @returns {URL} Remote URL to get the manifest from.
 */
export function getRemoteURL(uri) {
    const remoteURL = new URL(remote);
    remoteURL.pathname = path.posix.join(remoteURL.pathname, uri);
    return remoteURL;
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
        local,
        parallelLimit,
        remote,
        sqlite3: debugMode ? sqlite3.verbose() : sqlite3,
        winston
    };
}

/**
 * Save a file with specific modified date.
 *
 * @param {string} path File path to write to.
 * @param {Buffer} buffer Whether to save the file to disk.
 * @param {Date | null | undefined} modifiedAt Modified date of the file, if applicable.
 *
 * @returns {Promise<void>} Fulfills with `undefined` with upon success.
 */
export async function saveFile(path, buffer, modifiedAt) {
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
                return [null, lastModified, false];
            }
        }
    }
    winston.info(`downloading from ${remoteURL}`);
    const response = await fetch(remoteURL);
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    const lastModified = getLastModifiedDate(response);
    if (save) {
        await saveFile(localPath, buffer, lastModified);
    }
    return [buffer, lastModified ?? null, true];
}
