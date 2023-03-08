import JSZip from 'jszip'
import fetch from 'node-fetch'
import os from 'os'
import path from 'path'
import process from 'process'
import winston from 'winston'
import { existsSync } from 'fs'
import { mkdir, mkdtemp, readFile, stat, utimes, writeFile } from 'fs/promises'

/** The remote URL of a pre-indexed WinGet source repository. */
const remote = process.env.WINGET_REPO_URL ?? 'https://cdn.winget.microsoft.com/cache';

/** The local path to serve as the root of WinGet source repository. */
const local = process.env.TO;

/** Maximum sync jobs to be executed in parallel. Defaults to 8. */
const parallelLimit = parseInt(process.env.WINGET_REPO_JOBS ?? 8);

/** Whether the debug mode is enabled. */
const debugMode = process.env.DEBUG === 'true';

/** Path of the log file to write. */
const logFile = process.env.LOGFILE;

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
 * @returns {string} Full URI resolved from the given ID.
 */
function resolvePathpart(id, pathparts) {
    const pathpart = pathparts.get(id);
    if (pathpart === undefined) return '';
    return path.posix.join(resolvePathpart(pathpart.parent, pathparts), pathpart.pathpart);
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
    if (error) {
        winston.error(error);
        process.exit(-1);
    }
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
    if (error) {
        winston.error(error);
        process.exit(-1);
    }
    return rows.map(row => resolvePathpart(row.pathpart, pathparts));
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
    const bundle = await readFile(msixPath);
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
    return await mkdtemp(path.join(os.tmpdir(), prefix));
}

/**
 * Check and return the required environment variables.
 *
 * @returns Environment variables to be used in the program.
 */
export function requireEnvironmentVariables() {
    if (!local || !logFile) {
        console.error("[ERROR] required environment variable(s) not set!");
        process.exit(-1);
    }
    return { debugMode, local, logFile, parallelLimit, remote };
}

/**
 * Set up the default `winston` logger instance.
 *
 * @param {boolean} debugMode Whether the debug mode is enabled.
 * @param {fs.PathLike} logFile Path of the log file to write.
 *
 * @returns The shared `winston` logger.
 */
export function setupWinstonLogger(debugMode, logFile) {
    const { format, transports } = winston;
    const logWithLevelPrefix = ({ level, message }) => `[${level.toUpperCase()}] ${message}`;
    winston.configure({
        transports: [
            new transports.File({
                level: 'verbose',
                filename: logFile,
                format: format.combine(
                    format.timestamp(),
                    format.printf((info) => `[${info.timestamp}]${logWithLevelPrefix(info)}`)
                )
            }),
            new transports.Console({
                level: debugMode ? 'debug' : 'info',
                stderrLevels: ['error'],
                format: format.printf(logWithLevelPrefix)
            })
        ]
    });
    return winston;
}

/**
 * Sync a file with the remote server asynchronously.
 *
 * @param {string} uri URI to sync.
 *
 * @returns {Promise<boolean>} If the file is new or updated.
 */
export async function syncFile(uri) {
    const localPath = getLocalPath(uri);
    const remoteURL = getRemoteURL(uri);
    await mkdir(path.dirname(localPath), { recursive: true });
    if (existsSync(localPath)) {
        const response = await fetch(remoteURL, { method: 'HEAD' });
        const lastModified = getLastModifiedDate(response);
        const contentLength = getContentLength(response);
        if (lastModified) {
            const localFile = await stat(localPath);
            if (localFile.mtime.getTime() == lastModified.getTime() && localFile.size == contentLength) {
                winston.verbose(`skipped ${uri} because it's up to date`);
                return false;
            }
        }
    }
    const response = await fetch(remoteURL);
    winston.verbose(`downloading from ${remoteURL}`);
    await writeFile(localPath, response.body);
    const lastModified = getLastModifiedDate(response);
    if (lastModified) {
        await utimes(localPath, lastModified, lastModified);
    }
    return true;
}
