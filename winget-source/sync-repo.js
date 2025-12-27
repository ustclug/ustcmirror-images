import assert from 'assert'
import async from 'async'

import { rm } from 'fs/promises'
import { AsyncDatabase } from 'promised-sqlite3'
import { EX_IOERR, EX_SOFTWARE, EX_TEMPFAIL, EX_UNAVAILABLE } from './sysexits.js'

import {
    buildManifestURIs,
    buildManifestURIsFromPackageMetadata,
    buildPackageMetadataURIs,
    buildPathpartMap,
    cacheFileWithURI,
    exitWithCode,
    extractDatabaseFromBundle,
    makeTempDirectory,
    setupEnvironment,
    syncFile,
} from './utilities.js'


const { forceSync, parallelLimit, remote, sqlite3, winston } = setupEnvironment();

/**
 * Sync with the official WinGet repository index.
 *
 * @param {number} version WinGet index version to sync.
 * @param {(db: AsyncDatabase) => Promise<void>} handler Handler function that reads the index database and syncs necessary files.
 *
 * @returns {Promise<void>} Fulfills with `undefined` upon success.
 */
async function syncIndex(version, handler) {
    const tempDirectory = await makeTempDirectory('winget-repo-');
    const sourceFilename = version > 1 ? `source${version}.msix` : 'source.msix';
    try {
        // download index package to buffer
        const [indexBuffer, modifiedDate, updated] = await syncFile(sourceFilename, true, false);
        if (!updated && !forceSync) {
            winston.info(`skip syncing index version ${version} from ${remote}`);
            return;
        }
        assert(Buffer.isBuffer(indexBuffer), 'Failed to get the source index buffer!');

        // unpack, extract and load index database
        try {
            const databaseFilePath = await extractDatabaseFromBundle(indexBuffer, tempDirectory);
            const database = new sqlite3.Database(databaseFilePath, sqlite3.OPEN_READONLY);
            try {
                // sync files with handler
                const asyncDatabase = new AsyncDatabase(database);
                await handler(asyncDatabase);
                await asyncDatabase.close();
            } catch (error) {
                exitWithCode(EX_SOFTWARE, error);
            }
        } catch (error) {
            exitWithCode(EX_IOERR, error);
        }

        // update index package
        if (updated) {
            await cacheFileWithURI(sourceFilename, indexBuffer, modifiedDate);
        }
    } catch (error) {
        try {
            await rm(tempDirectory, { recursive: true });
        } finally {
            exitWithCode(EX_UNAVAILABLE, error);
        }
    }
    winston.info(`successfully synced version ${version} from ${remote}`);
    await rm(tempDirectory, { recursive: true });
}

winston.info(`start syncing with ${remote}`);

await syncIndex(2, async (db) => {
    try {
        const packageURIs = buildPackageMetadataURIs(await db.all('SELECT id, hash FROM packages'));
        try {
            // sync latest package metadata and manifests in parallel
            await async.eachLimit(packageURIs, parallelLimit, async (uri) => {
                const [metadataBuffer, modifiedDate, updated] = await syncFile(uri, forceSync, false);
                if (metadataBuffer) {
                    const manifestURIs = await buildManifestURIsFromPackageMetadata(metadataBuffer);
                    await async.eachSeries(manifestURIs, async (uri) => await syncFile(uri, forceSync));
                    if (updated) {
                        await cacheFileWithURI(uri, metadataBuffer, modifiedDate);
                    }
                }
            });
        } catch (error) {
            exitWithCode(EX_TEMPFAIL, error);
        }
    } catch (error) {
        exitWithCode(EX_SOFTWARE, error);
    }
});

await syncIndex(1, async (db) => {
    try {
        const pathparts = buildPathpartMap(await db.all('SELECT * FROM pathparts'));
        const uris = buildManifestURIs(await db.all('SELECT pathpart FROM manifest ORDER BY rowid DESC'), pathparts);
        // sync latest manifests in parallel
        try {
            await async.eachLimit(uris, parallelLimit, async (uri) => await syncFile(uri, forceSync));
        } catch (error) {
            exitWithCode(EX_TEMPFAIL, error);
        }
    } catch (error) {
        exitWithCode(EX_SOFTWARE, error);
    }
});

winston.info(`successfully synced with ${remote}`);
