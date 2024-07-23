import assert from 'assert'
import async from 'async'

import { rm } from 'fs/promises'
import { AsyncDatabase } from 'promised-sqlite3'
import { EX_IOERR, EX_OK, EX_SOFTWARE, EX_TEMPFAIL, EX_UNAVAILABLE } from './sysexits.js'

import {
    buildPathpartMap,
    buildManifestURIs,
    exitWithCode,
    extractDatabaseFromBundle,
    getLocalPath,
    makeTempDirectory,
    saveFile,
    setupEnvironment,
    syncFile,
    buildPackageMetadataURIs,
    buildManifestURIsFromPackageMetadata
} from './utilities.js'


const sourceV1Filename = 'source.msix';
const sourceV2Filename = 'source2.msix';

// set up configs and temp directory
const { parallelLimit, remote, sqlite3, winston } = setupEnvironment();
const tempDirectory = await makeTempDirectory('winget-repo-');

winston.info(`start syncing with ${remote}`);

try {
    // download V1 index package to buffer
    const [indexBuffer, modifiedDate, updated] = await syncFile(sourceV1Filename, true, false);
    if (!updated) {
        winston.info(`nothing to sync from ${remote}`);
        exitWithCode(EX_OK);
    }
    assert(indexBuffer !== null, "Failed to get the source index buffer!");

    // unpack, extract and load V1 index database
    try {
        const databaseFilePath = await extractDatabaseFromBundle(indexBuffer, tempDirectory);
        const rawDatabase = new sqlite3.Database(databaseFilePath, sqlite3.OPEN_READONLY);

        // read manifest URIs from index database
        try {
            const db = new AsyncDatabase(rawDatabase)
            const pathparts = buildPathpartMap(await db.all('SELECT * FROM pathparts'));
            const uris = buildManifestURIs(await db.all('SELECT pathpart FROM manifest ORDER BY rowid DESC'), pathparts);
            await db.close();

            // sync latest manifests in parallel
            try {
                await async.eachLimit(uris, parallelLimit, async (uri) => await syncFile(uri, false));
            } catch (error) {
                exitWithCode(EX_TEMPFAIL, error);
            }
        } catch (error) {
            exitWithCode(EX_SOFTWARE, error);
        }
    } catch (error) {
        exitWithCode(EX_IOERR, error);
    }

    // update index package
    await saveFile(getLocalPath(sourceV1Filename), indexBuffer, modifiedDate);
} catch (error) {
    exitWithCode(EX_UNAVAILABLE, error);
}

try {
    // download V2 index package to buffer
    const [indexBuffer, modifiedDate, updated] = await syncFile(sourceV2Filename, true, false);
    if (!updated) {
        winston.info(`skip syncing V2 from ${remote}`);
        exitWithCode(EX_OK);
    }
    assert(indexBuffer !== null, "Failed to get the source index buffer!");

    // unpack, extract and load V2 index database
    try {
        const databaseFilePath = await extractDatabaseFromBundle(indexBuffer, tempDirectory);
        const rawDatabase = new sqlite3.Database(databaseFilePath, sqlite3.OPEN_READONLY);

        // read package URIs from index database
        try {
            const db = new AsyncDatabase(rawDatabase)
            const packageURIs = buildPackageMetadataURIs(await db.all('SELECT id, hash FROM packages'));
            await db.close();

            // sync latest package metadata and manifests in parallel
            try {
                const manifestURIs = await async.concatLimit(packageURIs, parallelLimit, async (uri) => {
                    const [metadataBuffer] = await syncFile(uri, false);
                    try {
                        return metadataBuffer ? await buildManifestURIsFromPackageMetadata(metadataBuffer) : [];
                    } catch (error) {
                        winston.error(`inspecting ${uri}`)
                        exitWithCode(EX_SOFTWARE, error);
                    }
                });
                await async.eachLimit(manifestURIs, parallelLimit, async (uri) => await syncFile(uri, false));
            } catch (error) {
                exitWithCode(EX_TEMPFAIL, error);
            }
        } catch (error) {
            exitWithCode(EX_SOFTWARE, error);
        }
    } catch (error) {
        exitWithCode(EX_IOERR, error);
    }

    // update index package
    await saveFile(getLocalPath(sourceV2Filename), indexBuffer, modifiedDate);
} catch (error) {
    exitWithCode(EX_UNAVAILABLE, error);
}

winston.info(`successfully synced with ${remote}`);

// clean up temp directory
await rm(tempDirectory, { recursive: true });
