import withRetry from 'fetch-retry'
import https from 'https'
import JSZip from 'jszip'
import originalFetch from 'node-fetch'
import os from 'os'
import path from 'path'
import process from 'process'
import sqlite3 from 'sqlite3'
import winston from 'winston'
import { existsSync } from 'fs'
import { mkdir, mkdtemp, readFile, stat, utimes, writeFile } from 'fs/promises'
import { EX_IOERR, EX_SOFTWARE, EX_USAGE } from './sysexits.js'

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
    if (pathpart === undefined) return '';
    return path.posix.join(resolvePathpart(pathpart.parent, pathparts), pathpart.pathpart);
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
 * @param {Error?} error Database error thrown from the query, if any.
 * @param {{ rowid: number, parent: number, pathpart: string }[]} rows Rows returned by the query.
 *
 * @returns {Map<number, { parent: number, pathpart: string }>} In-memory path part storage to query against.
 */
export function buildPathpartMap(error, rows) {
    exitOnError(EX_SOFTWARE)(error);
    return new Map(rows.map(row =>
        [row.rowid, { parent: row.parent, pathpart: row.pathpart }]
    ));
}

/**
 * Build a list of all manifest URIs from database query.
 *
 * @param {Error?} error Database error thrown from the query, if any.
 * @param {{ pathpart: string, [key: string]: string }[]} rows Rows returned by the query.
 * @param {Map<number, { parent: number, pathpart: string }>} pathparts Path part storage built from the database.
 *
 * @returns {string[]} Manifest URIs to sync.
 */
export function buildURIList(error, rows, pathparts) {
    exitOnError(EX_SOFTWARE)(error);
    return rows.map(row => resolvePathpart(row.pathpart, pathparts));
}

/**
 * Get an error handling function that logs an error and exits with given status if it occurs.
 *
 * @param {number} code Exit code to use if there's an error.
 *
 * @returns {(err: Error | string | null | undefined) => void} Function that handles a possible error.
 */
export function exitOnError(code = 1) {
    return (error) => {
        if (error) {
            winston.exitOnError = false;
            winston.error(error);
            process.exit(code);
        }
    };
}

/**
 * Extract database file from the source bundle.
 *
 * @param {fs.PathLike} msixPath Path of the MSIX bundle file.
 * @param {fs.PathLike} directory Path of directory to save the file.
 *
 * @returns {Promise<string>} Path of the extracted `index.db` file.
 */
export async function extractDatabaseFromBundle(msixPath, directory) {
    try {
        const bundle = await readFile(msixPath);
        const zip = await JSZip.loadAsync(bundle);
        const buffer = await zip.file(path.posix.join('Public', 'index.db')).async('Uint8Array');
        const destination = path.join(directory, 'index.db');
        await writeFile(destination, buffer);
        return destination;
    } catch (error) {
        exitOnError(EX_IOERR)(error);
    }
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
        exitOnError(EX_IOERR)(error);
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
        exitOnError(EX_USAGE)("destination path $TO not set!");
    }
    if (localAddress) {
        https.globalAgent.options.localAddress = localAddress;
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
 * Sync a file with the remote server asynchronously.
 *
 * @param {string} uri URI to sync.
 * @param {boolean} update Whether to allow updating an existing file.
 * @param {boolean} saveAsTmp Whether to save with ".tmp" suffix 
 *
 * @returns {Promise<boolean>} If the file is new or updated.
 */
export async function syncFile(uri, update = true, saveAsTmp = false) {
    const localPath = getLocalPath(saveAsTmp ? uri + ".tmp" : uri);
    const remoteURL = getRemoteURL(uri);
    await mkdir(path.dirname(localPath), { recursive: true });
    if (existsSync(localPath)) {
        if (!update) {
            winston.debug(`skipped ${uri} because it already exists`);
            return false;
        }
        const response = await fetch(remoteURL, { method: 'HEAD' });
        const lastModified = getLastModifiedDate(response);
        const contentLength = getContentLength(response);
        if (lastModified) {
            const localFile = await stat(localPath);
            if (localFile.mtime.getTime() == lastModified.getTime() && localFile.size == contentLength) {
                winston.debug(`skipped ${uri} because it's up to date`);
                return false;
            }
        }
    }
    winston.info(`downloading from ${remoteURL}`);
    const response = await fetch(remoteURL);
    const buffer = await response.arrayBuffer();
    await writeFile(localPath, Buffer.from(buffer));
    const lastModified = getLastModifiedDate(response);
    if (lastModified) {
        await utimes(localPath, lastModified, lastModified);
    }
    return true;
}
