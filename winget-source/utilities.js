import crypto from 'crypto'
import JSZip from 'jszip'
import fetch from 'node-fetch'
import os from 'os'
import path from 'path'
import process from 'process'
import { existsSync } from 'fs'
import { mkdir, mkdtemp, readFile, utimes, writeFile } from 'fs/promises'

const remote = process.env.WINGET_REPO_URL;
const local = process.env.TO;
const parallelLimit = parseInt(process.env.WINGET_REPO_JOBS ?? 8);

/**
 * @param {number} id
 * @param {Map<number, { parent: number, pathpart: string }>} pathparts
 *
 * @returns {string}
 */
function resolvePathpart(id, pathparts) {
    const pathpart = pathparts.get(id);
    if (pathpart === undefined) return '';
    return path.posix.join(resolvePathpart(pathpart.parent, pathparts), pathpart.pathpart);
}

/**
 * @param {crypto.BinaryLike} buffer
 * @param {crypto.BinaryToTextEncoding} encoding
 *
 * @returns {string}
 */
function computeMD5(buffer, encoding) {
    const hash = crypto.createHash('md5');
    hash.update(buffer, 'utf-8');
    return hash.digest(encoding);
}

/**
 * @param {Error?} error
 * @param {{ rowid: number, parent: number, pathpart: string }[]} rows
 *
 * @returns {Map<number, { parent: number, pathpart: string }>}
 */
export function buildPathpartMap(error, rows) {
    if (error) {
        console.error(error);
        process.exit(-1);
    }
    return new Map(rows.map(row =>
        [row.rowid, { parent: row.parent, pathpart: row.pathpart }]
    ));
}

/**
 * @param {Error?} error
 * @param {{ pathpart: string, [key: string]: string }[]} rows
 * @param {Map<number, { parent: number, pathpart: string }>} pathparts
 *
 * @returns {string[]}
 */
export function buildUriList(error, rows, pathparts) {
    if (error) {
        console.error(error);
        process.exit(-1);
    }
    return rows.map(row => resolvePathpart(row.pathpart, pathparts));
}

export function checkEnvironmentVariables() {
    if (!remote || !local || !parallelLimit) {
        console.error("required envirenent variable(s) not set!");
        process.exit(-1);
    }
    return { remote, local, parallelLimit };
}

/**
 * @param {fs.PathLike} msixPath
 * @param {fs.PathLike} tempDirectory
 *
 * @returns {Promise<string>}
 */
export async function exatractDBFromBundle(msixPath, tempDirectory) {
    const bundle = await readFile(msixPath);
    const zip = await JSZip.loadAsync(bundle);
    const buffer = await zip.file(path.posix.join('Public', 'index.db')).async('Uint8Array');
    const destination = path.join(tempDirectory, 'index.db');
    await writeFile(destination, buffer);
    return destination;
}

/**
 * @param {string} uri
 *
 * @returns {string}
 */
export function getLocalPath(uri) {
    return path.join(local, uri);
}

/**
 * @param {string} uri
 *
 * @returns {URL}
 */
export function getRemoteURL(uri) {
    return new URL(`${remote}/${uri}`);
}

/**
 * @param {string} prefix
 *
 * @returns {Promise<string>}
 */
export async function makeTempDirectory(prefix) {
    return await mkdtemp(path.join(os.tmpdir(), prefix));
}

/**
 * @param {string} uri
 *
 * @returns {Promise<boolean>}
 */
export async function syncFile(uri) {
    const localPath = getLocalPath(uri);
    const remoteURL = getRemoteURL(uri);
    await mkdir(path.dirname(localPath), { recursive: true });
    if (existsSync(localPath)) {
        const response = await fetch(remoteURL, { method: 'HEAD' });
        const latestMD5 = response.headers.get('Content-MD5');
        if (latestMD5) {
            const buffer = await readFile(localPath);
            const md5 = computeMD5(buffer, 'base64');
            if (latestMD5 === md5) {
                console.info(`skipped ${uri} because it's up to date`);
                return false;
            }
        }
    }
    const response = await fetch(remoteURL);
    console.log(`downloaded ${uri}`);
    await writeFile(localPath, response.body);
    const lastModified = response.headers.get('Last-Modified');
    if (lastModified) {
        const date = new Date(lastModified);
        await utimes(localPath, date, date);
    }
    return true;
}
